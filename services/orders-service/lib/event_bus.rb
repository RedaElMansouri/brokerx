# frozen_string_literal: true

require 'redis'
require 'json'
require 'securerandom'

# EventBus - Redis Pub/Sub for choreographed saga pattern
# Enables asynchronous event-driven communication between microservices
module EventBus
  # Event types for UC-07 (Order Matching & Execution)
  module Events
    ORDER_REQUESTED = 'order.requested'
    ORDER_PLACED = 'order.placed'
    ORDER_CANCELLED = 'order.cancelled'
    ORDER_MATCHED = 'order.matched'
    EXECUTION_REPORT = 'execution.report'
    TRADE_EXECUTED = 'trade.executed'
    
    FUNDS_RESERVED = 'funds.reserved'
    FUNDS_RELEASED = 'funds.released'
    FUNDS_RESERVATION_FAILED = 'funds.reservation_failed'
    POSITION_UPDATED = 'position.updated'
  end

  class << self
    def redis
      @redis ||= Redis.new(
        url: eventbus_redis_url,
        timeout: 5
      )
    end

    def subscriber_redis
      @subscriber_redis ||= Redis.new(
        url: eventbus_redis_url,
        timeout: 0
      )
    end

    # Use a separate DB for EventBus (DB 15) to avoid conflicts with service-specific caches
    def eventbus_redis_url
      base_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
      # Replace the DB number with 15 for EventBus
      base_url.gsub(%r{/\d+$}, '/15')
    end

    # Publish an event to Redis
    def publish(event_type, data, correlation_id: nil)
      event = build_event(event_type, data, correlation_id)
      
      channel = "eventbus:#{event_type}"
      redis.publish(channel, event.to_json)
      store_event(event)
      
      Rails.logger.info("[EventBus] Published #{event_type}: #{event[:id]}")
      event
    rescue Redis::BaseError => e
      Rails.logger.error("[EventBus] Publish failed: #{e.message}")
      raise EventBusError, "Failed to publish event: #{e.message}"
    end

    # Subscribe to events (blocking - run in separate thread)
    def subscribe(*event_types, &block)
      channels = event_types.map { |t| "eventbus:#{t}" }
      
      Rails.logger.info("[EventBus] Subscribing to: #{event_types.join(', ')}")
      
      subscriber_redis.subscribe(*channels) do |on|
        on.message do |_channel, message|
          event = JSON.parse(message, symbolize_names: true)
          Rails.logger.info("[EventBus] Received #{event[:type]}: #{event[:id]}")
          
          begin
            block.call(event)
            mark_event_processed(event[:id])
          rescue StandardError => e
            Rails.logger.error("[EventBus] Handler failed: #{e.message}")
            Rails.logger.error(e.backtrace.first(5).join("\n"))
          end
        end
      end
    rescue Redis::BaseError => e
      Rails.logger.error("[EventBus] Subscribe failed: #{e.message}")
      raise EventBusError, "Failed to subscribe: #{e.message}"
    end

    # Non-blocking subscription
    def subscribe_async(*event_types, handler:)
      Thread.new do
        subscribe(*event_types) do |event|
          handler.handle(event)
        end
      end
    end

    # Check if event was already processed
    def processed?(event_id)
      redis.sismember('eventbus:processed', event_id)
    end

    # Get event history for a type
    def history(event_type, limit: 100)
      key = "eventbus:events:#{event_type}"
      events = redis.zrevrange(key, 0, limit - 1)
      events.map { |e| JSON.parse(e, symbolize_names: true) }
    end

    # Stats for monitoring
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
        source: ENV.fetch('SERVICE_NAME', 'orders-service'),
        correlation_id: correlation_id || SecureRandom.uuid,
        timestamp: Time.current.iso8601(3),
        data: data
      }
    end

    def store_event(event)
      key = "eventbus:events:#{event[:type]}"
      score = Time.parse(event[:timestamp]).to_f
      
      redis.zadd(key, score, event.to_json)
      redis.zremrangebyrank(key, 0, -10001)
    end

    def mark_event_processed(event_id)
      redis.sadd('eventbus:processed', event_id)
      redis.expire('eventbus:processed', 7 * 24 * 3600)
    end
  end

  class EventBusError < StandardError; end
end
