# frozen_string_literal: true

require 'redis'
require 'json'
require 'securerandom'

# EventBus - Redis Pub/Sub for choreographed saga pattern
# Shared module - same as orders-service
#
module EventBus
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
    
    CLIENT_REGISTERED = 'client.registered'
    CLIENT_VERIFIED = 'client.verified'
  end

  class << self
    def redis
      @redis ||= Redis.new(
        url: eventbus_redis_url,
        timeout: 5,
        reconnect_attempts: 3
      )
    end

    def subscriber_redis
      @subscriber_redis ||= Redis.new(
        url: eventbus_redis_url,
        timeout: 0,
        reconnect_attempts: 3
      )
    end

    # Use a separate DB for EventBus (DB 15) to avoid conflicts with service-specific caches
    def eventbus_redis_url
      base_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
      # Replace the DB number with 15 for EventBus
      base_url.gsub(%r{/\d+$}, '/15')
    end

    def publish(event_type, data, correlation_id: nil)
      event = build_event(event_type, data, correlation_id)
      channel = "eventbus:#{event_type}"
      
      redis.publish(channel, event.to_json)
      store_event(event)
      
      Rails.logger.info("[EventBus] Published #{event_type}: #{event[:id]}")
      event
    rescue Redis::BaseError => e
      Rails.logger.error("[EventBus] Publish failed: #{e.message}")
      raise
    end

    def subscribe(*event_types, &block)
      channels = event_types.map { |t| "eventbus:#{t}" }
      
      Rails.logger.info("[EventBus] Subscribing to: #{event_types.join(', ')}")
      
      subscriber_redis.subscribe(*channels) do |on|
        on.message do |_channel, message|
          event = JSON.parse(message, symbolize_names: true)
          block.call(event)
        end
      end
    end

    def processed?(event_id)
      redis.sismember('eventbus:processed', event_id)
    end

    def mark_processed(event_id)
      redis.sadd('eventbus:processed', event_id)
    end

    private

    def build_event(event_type, data, correlation_id)
      {
        id: SecureRandom.uuid,
        type: event_type,
        source: 'portfolios-service',
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
  end

  class EventBusError < StandardError; end
end
