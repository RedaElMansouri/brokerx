# frozen_string_literal: true

# Integration Test for UC-07 Choreographed Saga
# Tests the event-driven order matching workflow between Orders and Portfolios services
#
# Run with:
#   docker exec brokerx-orders-service bundle exec rails runner test/integration/choreographed_saga_test.rb
#

require Rails.root.join('lib/event_bus')

module ChoreographedSagaTest
  class << self
    def run
      puts "=" * 60
      puts "UC-07 Choreographed Saga Integration Test"
      puts "=" * 60
      puts ""

      @passed = 0
      @failed = 0

      test_eventbus_connectivity
      test_order_creation_with_pending_funds
      test_event_publication
      test_event_storage
      test_correlation_id_propagation
      test_idempotency

      puts ""
      puts "=" * 60
      puts "Results: #{@passed} passed, #{@failed} failed"
      puts "=" * 60

      @failed.zero?
    end

    private

    def test_eventbus_connectivity
      puts "Test: EventBus connectivity to Redis..."
      
      begin
        pong = EventBus.redis.ping
        assert_equal("PONG", pong, "Redis should respond with PONG")
        pass("EventBus connected to Redis")
      rescue StandardError => e
        fail("EventBus connectivity failed: #{e.message}")
      end
    end

    def test_order_creation_with_pending_funds
      puts "Test: Order creation with pending_funds status..."
      
      order = Order.create!(
        client_id: "test-client-#{SecureRandom.hex(4)}",
        symbol: "AAPL",
        direction: "buy",
        order_type: "limit",
        quantity: 10,
        price: 150.0,
        status: "pending_funds"
      )
      
      assert_equal("pending_funds", order.status, "Order should have pending_funds status")
      pass("Order created with pending_funds status")
    rescue StandardError => e
      fail("Order creation failed: #{e.message}")
    end

    def test_event_publication
      puts "Test: Event publication to Redis..."
      
      event = EventBus.publish(EventBus::Events::ORDER_REQUESTED, {
        order_id: SecureRandom.uuid,
        client_id: SecureRandom.uuid,
        symbol: "AAPL",
        direction: "buy",
        quantity: 10,
        price: 150.0
      })
      
      assert(event[:id].present?, "Event should have an ID")
      assert(event[:correlation_id].present?, "Event should have a correlation ID")
      assert_equal("order.requested", event[:type], "Event type should be order.requested")
      pass("Event published successfully")
    rescue StandardError => e
      fail("Event publication failed: #{e.message}")
    end

    def test_event_storage
      puts "Test: Event storage in Redis..."
      
      before_count = EventBus.redis.zcard("eventbus:events:order.requested")
      
      EventBus.publish(EventBus::Events::ORDER_REQUESTED, {
        order_id: SecureRandom.uuid,
        test: "storage_test"
      })
      
      after_count = EventBus.redis.zcard("eventbus:events:order.requested")
      assert(after_count > before_count, "Event count should increase after publishing")
      pass("Events are stored in Redis")
    rescue StandardError => e
      fail("Event storage test failed: #{e.message}")
    end

    def test_correlation_id_propagation
      puts "Test: Correlation ID propagation..."
      
      correlation_id = SecureRandom.uuid
      
      # Simulate order.requested from Orders Service
      order_event = EventBus.publish(EventBus::Events::ORDER_REQUESTED, {
        order_id: SecureRandom.uuid,
        symbol: "AAPL"
      }, correlation_id: correlation_id)
      
      # Simulate funds.reserved from Portfolios Service with same correlation ID
      funds_event = EventBus.publish(EventBus::Events::FUNDS_RESERVED, {
        order_id: order_event[:data][:order_id],
        reserved_amount: 1500.0
      }, correlation_id: correlation_id)
      
      assert_equal(correlation_id, order_event[:correlation_id], "Order event should have the specified correlation ID")
      assert_equal(correlation_id, funds_event[:correlation_id], "Funds event should have the same correlation ID")
      pass("Correlation ID properly propagated")
    rescue StandardError => e
      fail("Correlation ID test failed: #{e.message}")
    end

    def test_idempotency
      puts "Test: Idempotency check..."
      
      event_id = SecureRandom.uuid
      
      # Manually add to processed set
      EventBus.redis.sadd('eventbus:processed', event_id)
      
      # Check if processed
      assert(EventBus.processed?(event_id), "Event should be marked as processed")
      
      # Check unprocessed event
      new_event_id = SecureRandom.uuid
      assert(!EventBus.processed?(new_event_id), "New event should not be processed")
      
      pass("Idempotency check works correctly")
    rescue StandardError => e
      fail("Idempotency test failed: #{e.message}")
    end

    def assert(condition, message)
      raise AssertionError, message unless condition
    end

    def assert_equal(expected, actual, message)
      raise AssertionError, "#{message} - Expected: #{expected}, Got: #{actual}" unless expected == actual
    end

    def pass(message)
      @passed += 1
      puts "  ✓ #{message}"
    end

    def fail(message)
      @failed += 1
      puts "  ✗ #{message}"
    end

    class AssertionError < StandardError; end
  end
end

# Run the tests
exit(ChoreographedSagaTest.run ? 0 : 1)
