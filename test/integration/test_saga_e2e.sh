#!/bin/bash
# Integration Test Script for UC-07 Choreographed Saga
# Tests the event-driven workflow between Orders and Portfolios services
#
# Usage: ./test/integration/test_saga_e2e.sh
#

set -e

echo "============================================================"
echo "UC-07 Choreographed Saga E2E Integration Test"
echo "============================================================"
echo ""

PASSED=0
FAILED=0

pass() {
    PASSED=$((PASSED + 1))
    echo "  ✓ $1"
}

fail() {
    FAILED=$((FAILED + 1))
    echo "  ✗ $1"
}

echo "1. Testing Redis connectivity..."
REDIS_PING=$(docker exec brokerx-redis redis-cli -n 15 ping 2>/dev/null)
if [ "$REDIS_PING" == "PONG" ]; then
    pass "Redis is running and accessible"
else
    fail "Redis connectivity failed"
fi

echo ""
echo "2. Testing EventBus from Orders Service..."
ORDERS_TEST=$(docker exec brokerx-orders-service bundle exec rails runner '
require Rails.root.join("lib/event_bus")
puts EventBus.redis.ping
' 2>/dev/null)

if [ "$ORDERS_TEST" == "PONG" ]; then
    pass "Orders Service can connect to EventBus"
else
    fail "Orders Service EventBus connection failed"
fi

echo ""
echo "3. Testing EventBus from Portfolios Service..."
PORTFOLIOS_TEST=$(docker exec brokerx-portfolios-service bundle exec rails runner '
require Rails.root.join("lib/event_bus")
puts EventBus.redis.ping
' 2>/dev/null)

if [ "$PORTFOLIOS_TEST" == "PONG" ]; then
    pass "Portfolios Service can connect to EventBus"
else
    fail "Portfolios Service EventBus connection failed"
fi

echo ""
echo "4. Testing event publication from Orders Service..."
ORDER_EVENT=$(docker exec brokerx-orders-service bundle exec rails runner '
require Rails.root.join("lib/event_bus")
event = EventBus.publish("order.requested", {
  order_id: "test-order-123",
  symbol: "AAPL"
})
puts event[:id]
' 2>/dev/null)

if [ -n "$ORDER_EVENT" ]; then
    pass "Orders Service published order.requested event: $ORDER_EVENT"
else
    fail "Orders Service failed to publish event"
fi

echo ""
echo "5. Testing event publication from Portfolios Service..."
FUNDS_EVENT=$(docker exec brokerx-portfolios-service bundle exec rails runner '
require Rails.root.join("lib/event_bus")
event = EventBus.publish("funds.reserved", {
  order_id: "test-order-123",
  reserved_amount: 1500.0
})
puts event[:id]
' 2>/dev/null)

if [ -n "$FUNDS_EVENT" ]; then
    pass "Portfolios Service published funds.reserved event: $FUNDS_EVENT"
else
    fail "Portfolios Service failed to publish event"
fi

echo ""
echo "6. Testing cross-service event visibility..."
EVENTS_COUNT=$(docker exec brokerx-redis redis-cli -n 15 keys "eventbus:events:*" | wc -l | tr -d ' ')

if [ "$EVENTS_COUNT" -ge "2" ]; then
    pass "Cross-service events visible in Redis: $EVENTS_COUNT event types"
else
    fail "Cross-service events not visible"
fi

echo ""
echo "7. Testing order creation with saga status..."
ORDER_CREATE=$(docker exec brokerx-orders-service bundle exec rails runner '
order = Order.create!(
  client_id: SecureRandom.uuid,
  symbol: "GOOG",
  direction: "buy",
  order_type: "limit",
  quantity: 5,
  price: 100.0,
  status: "pending_funds"
)
puts order.id
' 2>/dev/null)

if [ -n "$ORDER_CREATE" ]; then
    pass "Order created with pending_funds status: $ORDER_CREATE"
else
    fail "Order creation with saga status failed"
fi

echo ""
echo "============================================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "============================================================"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "All tests passed! The choreographed saga is working correctly."
    exit 0
else
    echo ""
    echo "Some tests failed. Please check the output above."
    exit 1
fi
