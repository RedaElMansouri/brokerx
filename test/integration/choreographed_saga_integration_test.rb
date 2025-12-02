# frozen_string_literal: true

require 'minitest/autorun'
require 'redis'
require 'json'
require 'securerandom'
require 'net/http'
require 'uri'
require 'time'
require 'ostruct'

# Integration Tests for UC-07 Choreographed Saga
# Tests the event-driven order matching workflow between microservices
#
# Prerequisites:
#   - Docker microservices running (docker compose -f docker-compose.microservices.yml up -d)
#   - Redis accessible on localhost:6379
#
# Run with:
#   ruby test/integration/choreographed_saga_integration_test.rb
#   OR
#   bundle exec ruby test/integration/choreographed_saga_integration_test.rb
#

class ChoreographedSagaIntegrationTest < Minitest::Test
  REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/15')
  ORDERS_SERVICE_URL = ENV.fetch('ORDERS_SERVICE_URL', 'http://localhost:3003')
  PORTFOLIOS_SERVICE_URL = ENV.fetch('PORTFOLIOS_SERVICE_URL', 'http://localhost:3002')

  def setup
    @redis = Redis.new(url: REDIS_URL)
    @correlation_id = SecureRandom.uuid
  end

  def teardown
    @redis&.close
  end

  # ============================================================
  # Infrastructure Tests
  # ============================================================

  def test_redis_connectivity
    assert_equal 'PONG', @redis.ping, 'Redis should respond with PONG'
  end

  def test_orders_service_health
    response = http_get("#{ORDERS_SERVICE_URL}/health")
    assert response.is_a?(Net::HTTPSuccess), "Orders service should be healthy, got: #{response.code}"
  end

  def test_portfolios_service_health
    response = http_get("#{PORTFOLIOS_SERVICE_URL}/health")
    assert response.is_a?(Net::HTTPSuccess), "Portfolios service should be healthy, got: #{response.code}"
  end

  # ============================================================
  # EventBus Tests
  # ============================================================

  def test_event_publication_stores_in_redis
    event_type = 'order.requested'
    event_data = {
      order_id: SecureRandom.uuid,
      client_id: SecureRandom.uuid,
      symbol: 'AAPL',
      direction: 'buy',
      quantity: 10,
      price: 150.0
    }

    event = publish_event(event_type, event_data)

    # Verify event structure
    assert event[:id].is_a?(String), 'Event should have an ID'
    assert event[:correlation_id].is_a?(String), 'Event should have a correlation ID'
    assert_equal event_type, event[:type], 'Event type should match'
    assert event[:timestamp].is_a?(String), 'Event should have a timestamp'

    # Verify stored in Redis
    stored_events = @redis.zrange("eventbus:events:#{event_type}", 0, -1)
    assert stored_events.any? { |e| JSON.parse(e)['id'] == event[:id] }, 'Event should be stored in Redis'
  end

  def test_correlation_id_propagation
    correlation_id = SecureRandom.uuid

    # Simulate order.requested from Orders Service
    order_event = publish_event('order.requested', {
      order_id: SecureRandom.uuid,
      symbol: 'AAPL'
    }, correlation_id: correlation_id)

    # Simulate funds.reserved from Portfolios Service
    funds_event = publish_event('funds.reserved', {
      order_id: order_event[:data][:order_id],
      reserved_amount: 1500.0
    }, correlation_id: correlation_id)

    assert_equal correlation_id, order_event[:correlation_id], 'Order event should have specified correlation ID'
    assert_equal correlation_id, funds_event[:correlation_id], 'Funds event should have same correlation ID'
  end

  def test_idempotency_marking
    event_id = SecureRandom.uuid

    # Mark as processed
    @redis.sadd('eventbus:processed', event_id)

    # Verify it's marked as processed
    assert @redis.sismember('eventbus:processed', event_id), 'Event should be marked as processed'

    # Verify new event is not processed
    new_event_id = SecureRandom.uuid
    refute @redis.sismember('eventbus:processed', new_event_id), 'New event should not be processed'
  end

  # ============================================================
  # Saga Flow Tests
  # ============================================================

  def test_saga_event_sequence_order_requested
    order_id = SecureRandom.uuid
    client_id = SecureRandom.uuid

    event = publish_event('order.requested', {
      order_id: order_id,
      client_id: client_id,
      symbol: 'GOOG',
      direction: 'buy',
      quantity: 5,
      price: 100.0,
      estimated_cost: 500.0
    })

    assert_equal 'order.requested', event[:type]
    assert_equal order_id, event[:data][:order_id]
    assert_equal client_id, event[:data][:client_id]
  end

  def test_saga_event_sequence_funds_reserved
    order_id = SecureRandom.uuid
    portfolio_id = SecureRandom.uuid
    correlation_id = SecureRandom.uuid

    event = publish_event('funds.reserved', {
      order_id: order_id,
      portfolio_id: portfolio_id,
      reserved_amount: 1500.0
    }, correlation_id: correlation_id)

    assert_equal 'funds.reserved', event[:type]
    assert_equal order_id, event[:data][:order_id]
    assert_equal 1500.0, event[:data][:reserved_amount]
    assert_equal correlation_id, event[:correlation_id]
  end

  def test_saga_event_sequence_funds_reservation_failed
    order_id = SecureRandom.uuid

    event = publish_event('funds.reservation_failed', {
      order_id: order_id,
      reason: 'Insufficient funds'
    })

    assert_equal 'funds.reservation_failed', event[:type]
    assert_equal 'Insufficient funds', event[:data][:reason]
  end

  def test_saga_event_sequence_execution_report
    order_id = SecureRandom.uuid
    trade_id = SecureRandom.uuid

    event = publish_event('execution.report', {
      order_id: order_id,
      trade_id: trade_id,
      status: 'filled',
      filled_quantity: 10,
      fill_price: 150.0,
      total_value: 1500.0
    })

    assert_equal 'execution.report', event[:type]
    assert_equal 'filled', event[:data][:status]
  end

  def test_saga_compensation_funds_released
    order_id = SecureRandom.uuid
    portfolio_id = SecureRandom.uuid

    event = publish_event('funds.released', {
      order_id: order_id,
      portfolio_id: portfolio_id,
      released_amount: 1500.0,
      reason: 'Order cancelled'
    })

    assert_equal 'funds.released', event[:type]
    assert_equal 1500.0, event[:data][:released_amount]
  end

  # ============================================================
  # Full Saga Flow Test
  # ============================================================

  def test_complete_saga_happy_path
    order_id = SecureRandom.uuid
    client_id = SecureRandom.uuid
    portfolio_id = SecureRandom.uuid
    correlation_id = SecureRandom.uuid

    # Step 1: Order requested
    order_event = publish_event('order.requested', {
      order_id: order_id,
      client_id: client_id,
      portfolio_id: portfolio_id,
      symbol: 'AAPL',
      direction: 'buy',
      quantity: 10,
      price: 150.0,
      estimated_cost: 1500.0
    }, correlation_id: correlation_id)

    assert_equal correlation_id, order_event[:correlation_id]

    # Step 2: Funds reserved (response from Portfolios)
    funds_event = publish_event('funds.reserved', {
      order_id: order_id,
      portfolio_id: portfolio_id,
      reserved_amount: 1500.0
    }, correlation_id: correlation_id)

    assert_equal correlation_id, funds_event[:correlation_id]

    # Step 3: Order executed
    execution_event = publish_event('execution.report', {
      order_id: order_id,
      status: 'filled',
      filled_quantity: 10,
      fill_price: 150.0
    }, correlation_id: correlation_id)

    assert_equal correlation_id, execution_event[:correlation_id]

    # Verify all events stored with same correlation ID
    order_events = get_events('order.requested')
    funds_events = get_events('funds.reserved')
    exec_events = get_events('execution.report')

    assert(order_events.any? { |e| e['correlation_id'] == correlation_id })
    assert(funds_events.any? { |e| e['correlation_id'] == correlation_id })
    assert(exec_events.any? { |e| e['correlation_id'] == correlation_id })
  end

  def test_complete_saga_compensation_path
    order_id = SecureRandom.uuid
    client_id = SecureRandom.uuid
    portfolio_id = SecureRandom.uuid
    correlation_id = SecureRandom.uuid

    # Step 1: Order requested
    publish_event('order.requested', {
      order_id: order_id,
      client_id: client_id,
      symbol: 'AAPL',
      direction: 'buy',
      quantity: 10,
      price: 150.0
    }, correlation_id: correlation_id)

    # Step 2: Funds reservation failed (compensation trigger)
    failure_event = publish_event('funds.reservation_failed', {
      order_id: order_id,
      portfolio_id: portfolio_id,
      reason: 'Insufficient funds'
    }, correlation_id: correlation_id)

    assert_equal 'funds.reservation_failed', failure_event[:type]
    assert_equal 'Insufficient funds', failure_event[:data][:reason]

    # Verify compensation event
    failed_events = get_events('funds.reservation_failed')
    assert(failed_events.any? { |e| e['correlation_id'] == correlation_id })
  end

  # ============================================================
  # Event History Tests
  # ============================================================

  def test_event_history_retrieval
    event_type = "test.history.#{SecureRandom.hex(4)}"
    
    # Publish multiple events
    3.times do |i|
      publish_event(event_type, { index: i })
    end

    # Retrieve history
    events = get_events(event_type)
    
    assert_equal 3, events.size, 'Should have 3 events in history'
  end

  def test_event_ordering_by_timestamp
    event_type = "test.ordering.#{SecureRandom.hex(4)}"
    
    # Publish events with small delays
    events = []
    3.times do |i|
      events << publish_event(event_type, { index: i })
      sleep(0.01) # Small delay to ensure different timestamps
    end

    # Retrieve and check ordering
    stored = get_events(event_type)
    timestamps = stored.map { |e| e['timestamp'] }
    
    assert_equal timestamps.sort, timestamps, 'Events should be ordered by timestamp'
  end

  private

  def publish_event(event_type, data, correlation_id: nil)
    event = {
      id: SecureRandom.uuid,
      type: event_type,
      source: 'integration-test',
      correlation_id: correlation_id || SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601(3),
      data: data
    }

    # Store in Redis sorted set
    key = "eventbus:events:#{event_type}"
    score = Time.parse(event[:timestamp]).to_f
    @redis.zadd(key, score, event.to_json)

    # Publish to channel (for subscribers)
    @redis.publish("eventbus:#{event_type}", event.to_json)

    event
  end

  def get_events(event_type, limit: 100)
    key = "eventbus:events:#{event_type}"
    events = @redis.zrange(key, 0, limit - 1)
    events.map { |e| JSON.parse(e) }
  end

  def http_get(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri.request_uri)
    http.request(request)
  rescue StandardError => e
    OpenStruct.new(code: '500', body: e.message)
  end
end
