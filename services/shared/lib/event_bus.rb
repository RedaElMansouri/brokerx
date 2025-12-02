# frozen_string_literal: true

require 'redis'
require 'json'
require 'securerandom'

# EventBus - Redis Pub/Sub for choreographed saga pattern
# Enables asynchronous event-driven communication between microservices
#
# Usage:
#   # Publishing events
#   EventBus.publish('order.placed', { order_id: '123', symbol: 'AAPL' })
#
#   # Subscribing to events (typically in an initializer or worker)
#   EventBus.subscribe('order.placed') do |event|
#     OrderPlacedHandler.new.handle(event)
#   end
#
# Event Structure:
#   {
#     id: "uuid",                    # Unique event ID for idempotency
#     type: "order.placed",          # Event type
#     source: "orders-service",      # Source service
#     correlation_id: "uuid",        # For tracing across services
#     timestamp: "2024-01-01T...",   # ISO8601 timestamp
#     data: { ... }                  # Event payload
#   }
#
module EventBus
  # Event types for UC-07 (Order Matching & Execution)
  module Events
    # Orders Service publishes
    ORDER_PLACED = 'order.placed'
    ORDER_CANCELLED = 'order.cancelled'
    ORDER_MATCHED = 'order.matched'
    EXECUTION_REPORT = 'execution.report'
    TRADE_EXECUTED = 'trade.executed'
    
    # Portfolios Service publishes
    FUNDS_RESERVED = 'funds.reserved'
    FUNDS_RELEASED = 'funds.released'
    FUNDS_RESERVATION_FAILED = 'funds.reservation_failed'
    POSITION_UPDATED = 'position.updated'
    
    # Clients Service publishes
    CLIENT_REGISTERED = 'client.registered'
    CLIENT_VERIFIED = 'client.verified'
  end

  class << self
    def redis
      @redis ||= Redis.new(
        url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
        timeout: 5,
        reconnect_attempts: 3
      )
    end

    def subscriber_redis
      # Separate connection for subscriptions (blocking operation)
      @subscriber_redis ||= Redis.new(
        url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
        timeout: 0, # No timeout for blocking subscribe
        reconnect_attempts: 3
      )
    end

    # Publish an event to Redis
    # @param event_type [String] The type of event (e.g., 'order.placed')
    # @param data [Hash] The event payload
    # @param correlation_id [String] Optional correlation ID for tracing
    # @return [Hash] The published event
    def publish(event_type, data, correlation_id: nil)
      event = build_event(event_type, data, correlation_id)
      
      # Publish to Redis channel
      channel = channel_for(event_type)
      redis.publish(channel, event.to_json)
      
      # Also store in event log for replay/debugging
      store_event(event)
      
      log_event('published', event)
      event
    rescue Redis::BaseError => e
      log_error('publish_failed', event_type, e)
      raise EventBusError, "Failed to publish event: #{e.message}"
    end

    # Subscribe to events (blocking - run in separate thread/worker)
    # @param event_types [Array<String>] Event types to subscribe to
    # @param block [Block] Handler block receiving the event
    def subscribe(*event_types, &block)
      channels = event_types.map { |t| channel_for(t) }
      
      Rails.logger.info("[EventBus] Subscribing to: #{event_types.join(', ')}")
      
      subscriber_redis.subscribe(*channels) do |on|
        on.message do |_channel, message|
          event = JSON.parse(message, symbolize_names: true)
          log_event('received', event)
          
          begin
            block.call(event)
            mark_event_processed(event[:id])
          rescue StandardError => e
            log_error('handler_failed', event[:type], e)
            mark_event_failed(event[:id], e.message)
          end
        end
      end
    rescue Redis::BaseError => e
      log_error('subscribe_failed', event_types.join(','), e)
      raise EventBusError, "Failed to subscribe: #{e.message}"
    end

    # Non-blocking subscription using threads
    # @param event_types [Array<String>] Event types to subscribe to
    # @param handler [Object] Handler object with #handle(event) method
    # @return [Thread] The subscriber thread
    def subscribe_async(*event_types, handler:)
      Thread.new do
        subscribe(*event_types) do |event|
          handler.handle(event)
        end
      end
    end

    # Replay events from a specific point (for recovery)
    # @param event_type [String] Event type to replay
    # @param from_timestamp [Time] Start time for replay
    # @param handler [Object] Handler to process replayed events
    def replay(event_type, from_timestamp:, handler:)
      key = event_log_key(event_type)
      min_score = from_timestamp.to_f
      max_score = Time.current.to_f
      
      events = redis.zrangebyscore(key, min_score, max_score)
      
      Rails.logger.info("[EventBus] Replaying #{events.size} events of type #{event_type}")
      
      events.each do |event_json|
        event = JSON.parse(event_json, symbolize_names: true)
        handler.handle(event)
      end
    end

    # Check if an event was already processed (idempotency)
    # @param event_id [String] The event ID
    # @return [Boolean]
    def processed?(event_id)
      redis.sismember('eventbus:processed', event_id)
    end

    # Get pending events count for monitoring
    # @return [Hash] Counts by event type
    def stats
      pattern = 'eventbus:events:*'
      keys = redis.keys(pattern)
      
      keys.each_with_object({}) do |key, stats|
        event_type = key.split(':').last
        stats[event_type] = redis.zcard(key)
      end
    end

    private

    def build_event(event_type, data, correlation_id)
      {
        id: SecureRandom.uuid,
        type: event_type,
        source: service_name,
        correlation_id: correlation_id || Thread.current[:correlation_id] || SecureRandom.uuid,
        timestamp: Time.current.iso8601(3),
        data: data
      }
    end

    def channel_for(event_type)
      "eventbus:#{event_type}"
    end

    def event_log_key(event_type)
      "eventbus:events:#{event_type}"
    end

    def store_event(event)
      key = event_log_key(event[:type])
      score = Time.parse(event[:timestamp]).to_f
      
      # Store with timestamp as score for time-based queries
      redis.zadd(key, score, event.to_json)
      
      # Trim old events (keep last 10000 per type)
      redis.zremrangebyrank(key, 0, -10001)
    end

    def mark_event_processed(event_id)
      redis.sadd('eventbus:processed', event_id)
      # Expire processed set entries after 7 days
      redis.expire('eventbus:processed', 7 * 24 * 3600)
    end

    def mark_event_failed(event_id, error_message)
      redis.hset('eventbus:failed', event_id, {
        error: error_message,
        timestamp: Time.current.iso8601
      }.to_json)
    end

    def service_name
      @service_name ||= ENV.fetch('SERVICE_NAME', 'unknown-service')
    end

    def log_event(action, event)
      Rails.logger.info({
        event: "eventbus.#{action}",
        event_id: event[:id],
        event_type: event[:type],
        correlation_id: event[:correlation_id],
        source: event[:source],
        timestamp: Time.current.iso8601(3)
      }.to_json)
    end

    def log_error(action, context, error)
      Rails.logger.error({
        event: "eventbus.#{action}",
        context: context,
        error: error.message,
        error_class: error.class.name,
        timestamp: Time.current.iso8601(3)
      }.to_json)
    end
  end

  class EventBusError < StandardError; end
end
