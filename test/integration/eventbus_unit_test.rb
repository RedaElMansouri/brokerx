# frozen_string_literal: true

require 'minitest/autorun'
require 'redis'
require 'json'
require 'securerandom'
require 'time'

# Unit Tests for EventBus Module
# Tests the EventBus implementation without requiring full microservices
#
# Prerequisites:
#   - Redis accessible on localhost:6379
#
# Run with:
#   ruby test/integration/eventbus_unit_test.rb
#

class EventBusUnitTest < Minitest::Test
  REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/15')

  def setup
    @redis = Redis.new(url: REDIS_URL)
    @test_prefix = "test:#{SecureRandom.hex(4)}"
  end

  def teardown
    # Cleanup test keys
    keys = @redis.keys("#{@test_prefix}:*")
    @redis.del(*keys) if keys.any?
    @redis&.close
  end

  # ============================================================
  # Event Structure Tests
  # ============================================================

  def test_event_has_required_fields
    event = build_event('test.event', { foo: 'bar' })

    assert event[:id].is_a?(String), 'Event must have an ID'
    assert event[:type].is_a?(String), 'Event must have a type'
    assert event[:source].is_a?(String), 'Event must have a source'
    assert event[:correlation_id].is_a?(String), 'Event must have a correlation ID'
    assert event[:timestamp].is_a?(String), 'Event must have a timestamp'
    assert event[:data].is_a?(Hash), 'Event must have data'
  end

  def test_event_id_is_uuid
    event = build_event('test.event', {})
    
    # UUID format: 8-4-4-4-12 hex characters
    uuid_regex = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    assert_match uuid_regex, event[:id], 'Event ID must be a valid UUID'
  end

  def test_event_timestamp_is_iso8601
    event = build_event('test.event', {})
    
    # Should not raise an error
    parsed = Time.parse(event[:timestamp])
    assert parsed.is_a?(Time), 'Timestamp must be parseable as Time'
  end

  def test_correlation_id_propagation
    correlation_id = SecureRandom.uuid
    event = build_event('test.event', {}, correlation_id: correlation_id)

    assert_equal correlation_id, event[:correlation_id]
  end

  def test_correlation_id_auto_generated
    event = build_event('test.event', {})
    
    refute_nil event[:correlation_id]
    refute_empty event[:correlation_id]
  end

  # ============================================================
  # Event Storage Tests
  # ============================================================

  def test_event_stored_in_sorted_set
    event_type = "#{@test_prefix}:storage"
    event = build_event(event_type, { test: true })
    
    store_event(event_type, event)

    stored = @redis.zrange("eventbus:events:#{event_type}", 0, -1)
    assert_equal 1, stored.size
    
    parsed = JSON.parse(stored.first)
    assert_equal event[:id], parsed['id']
  end

  def test_events_sorted_by_timestamp
    event_type = "#{@test_prefix}:sorted"
    
    events = []
    3.times do |i|
      event = build_event(event_type, { index: i })
      store_event(event_type, event)
      events << event
      sleep 0.01 # Ensure different timestamps
    end

    stored = @redis.zrange("eventbus:events:#{event_type}", 0, -1)
    assert_equal 3, stored.size

    # Verify ordering
    stored_events = stored.map { |e| JSON.parse(e) }
    timestamps = stored_events.map { |e| Time.parse(e['timestamp']) }
    assert_equal timestamps.sort, timestamps
  end

  def test_event_retrieval_by_score
    event_type = "#{@test_prefix}:score"
    start_time = Time.now.utc

    sleep 0.1
    event = build_event(event_type, { after_start: true })
    store_event(event_type, event)

    # Query events after start_time
    results = @redis.zrangebyscore(
      "eventbus:events:#{event_type}",
      start_time.to_f,
      '+inf'
    )

    assert_equal 1, results.size
  end

  # ============================================================
  # Idempotency Tests
  # ============================================================

  def test_mark_event_as_processed
    event_id = SecureRandom.uuid

    refute @redis.sismember('eventbus:processed', event_id)

    @redis.sadd('eventbus:processed', event_id)

    assert @redis.sismember('eventbus:processed', event_id)
  end

  def test_check_if_event_processed
    event_id = SecureRandom.uuid
    new_event_id = SecureRandom.uuid

    @redis.sadd('eventbus:processed', event_id)

    assert @redis.sismember('eventbus:processed', event_id)
    refute @redis.sismember('eventbus:processed', new_event_id)
  end

  # ============================================================
  # Pub/Sub Tests
  # ============================================================

  def test_publish_to_channel
    event_type = "#{@test_prefix}:pubsub"
    channel = "eventbus:#{event_type}"
    received_messages = []

    # Subscribe in a separate thread
    subscriber = Thread.new do
      sub_redis = Redis.new(url: REDIS_URL)
      sub_redis.subscribe(channel) do |on|
        on.message do |_channel, message|
          received_messages << JSON.parse(message)
          sub_redis.unsubscribe if received_messages.size >= 1
        end
      end
      sub_redis.close
    end

    # Give subscriber time to connect
    sleep 0.5

    # Publish event
    event = build_event(event_type, { published: true })
    @redis.publish(channel, event.to_json)

    # Wait for message to be received
    subscriber.join(5)

    assert_equal 1, received_messages.size
    assert_equal event[:id], received_messages.first['id']
  end

  # ============================================================
  # Event Types Tests (UC-07)
  # ============================================================

  def test_order_requested_event_structure
    event = build_event('order.requested', {
      order_id: SecureRandom.uuid,
      client_id: SecureRandom.uuid,
      portfolio_id: SecureRandom.uuid,
      symbol: 'AAPL',
      direction: 'buy',
      quantity: 10,
      price: 150.0,
      estimated_cost: 1500.0
    })

    assert_equal 'order.requested', event[:type]
    assert event[:data][:order_id]
    assert event[:data][:client_id]
    assert event[:data][:symbol]
  end

  def test_funds_reserved_event_structure
    event = build_event('funds.reserved', {
      order_id: SecureRandom.uuid,
      portfolio_id: SecureRandom.uuid,
      reserved_amount: 1500.0
    })

    assert_equal 'funds.reserved', event[:type]
    assert event[:data][:order_id]
    assert_equal 1500.0, event[:data][:reserved_amount]
  end

  def test_funds_reservation_failed_event_structure
    event = build_event('funds.reservation_failed', {
      order_id: SecureRandom.uuid,
      portfolio_id: SecureRandom.uuid,
      reason: 'Insufficient funds'
    })

    assert_equal 'funds.reservation_failed', event[:type]
    assert_equal 'Insufficient funds', event[:data][:reason]
  end

  def test_execution_report_event_structure
    event = build_event('execution.report', {
      order_id: SecureRandom.uuid,
      trade_id: SecureRandom.uuid,
      status: 'filled',
      filled_quantity: 10,
      fill_price: 150.0
    })

    assert_equal 'execution.report', event[:type]
    assert_equal 'filled', event[:data][:status]
  end

  def test_funds_released_event_structure
    event = build_event('funds.released', {
      order_id: SecureRandom.uuid,
      portfolio_id: SecureRandom.uuid,
      released_amount: 1500.0,
      reason: 'Order cancelled'
    })

    assert_equal 'funds.released', event[:type]
    assert_equal 1500.0, event[:data][:released_amount]
  end

  private

  def build_event(event_type, data, correlation_id: nil)
    {
      id: SecureRandom.uuid,
      type: event_type,
      source: 'unit-test',
      correlation_id: correlation_id || SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601(3),
      data: data
    }
  end

  def store_event(event_type, event)
    key = "eventbus:events:#{event_type}"
    score = Time.parse(event[:timestamp]).to_f
    @redis.zadd(key, score, event.to_json)
  end
end
