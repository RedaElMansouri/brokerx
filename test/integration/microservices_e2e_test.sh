#!/bin/bash
# E2E Integration Test for BrokerX Microservices
# Tests the complete flow: Register -> Verify -> Login -> MFA -> Deposit -> Place Order

set -e

BASE_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)
EMAIL="test_e2e_${TIMESTAMP}@example.com"
PASSWORD="SecurePass123!"

echo "=========================================="
echo "BrokerX Microservices E2E Integration Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}→ $1${NC}"; }

# 1. Register New Client
info "1. Registering new client: $EMAIL"
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/clients" \
  -H "Content-Type: application/json" \
  -d "{\"client\":{\"email\":\"$EMAIL\",\"name\":\"Test User\",\"password\":\"$PASSWORD\"}}")

CLIENT_ID=$(echo $REGISTER_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('client_id', d.get('client',{}).get('id','')))" 2>/dev/null)
VERIFICATION_TOKEN=$(echo $REGISTER_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('verification_token',''))" 2>/dev/null)

if [ -z "$CLIENT_ID" ]; then
  echo "Response: $REGISTER_RESPONSE"
  fail "Registration failed - no client_id"
fi
pass "Registered client: $CLIENT_ID"

# 2. Verify Email
info "2. Verifying email..."
VERIFY_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/clients/$CLIENT_ID/verify_email?token=$VERIFICATION_TOKEN")
SUCCESS=$(echo $VERIFY_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print('verified' in d.get('message','').lower() or d.get('success',False))" 2>/dev/null)

if [ "$SUCCESS" != "True" ]; then
  echo "Response: $VERIFY_RESPONSE"
  fail "Email verification failed"
fi
pass "Email verified"

# 3. Login
info "3. Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

SESSION_TOKEN=$(echo $LOGIN_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_token',''))" 2>/dev/null)
MFA_CODE=$(echo $LOGIN_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('mfa_code',''))" 2>/dev/null)

if [ -z "$SESSION_TOKEN" ]; then
  echo "Response: $LOGIN_RESPONSE"
  fail "Login failed - no session_token"
fi
pass "Login successful, MFA code received"

# 4. Verify MFA
info "4. Verifying MFA..."
MFA_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/verify_mfa" \
  -H "Content-Type: application/json" \
  -d "{\"session_token\":\"$SESSION_TOKEN\",\"mfa_code\":\"$MFA_CODE\"}")

JWT_TOKEN=$(echo $MFA_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

if [ -z "$JWT_TOKEN" ]; then
  echo "Response: $MFA_RESPONSE"
  fail "MFA verification failed - no token"
fi
pass "MFA verified, JWT token received"

# 5. Get Current User (test auth)
info "5. Testing authentication (GET /me)..."
ME_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/me" \
  -H "Authorization: Bearer $JWT_TOKEN")

ME_EMAIL=$(echo $ME_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('email', d.get('client',{}).get('email','')))" 2>/dev/null)

if [ -z "$ME_EMAIL" ]; then
  echo "Response: $ME_RESPONSE"
  fail "Get current user failed"
fi
pass "Authentication working - got user: $ME_EMAIL"

# 6. Create Deposit (Portfolios Service)
info "6. Creating deposit of \$10,000..."
DEPOSIT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/deposits" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: deposit-$TIMESTAMP" \
  -d "{\"amount\":10000.00,\"currency\":\"USD\"}")

DEPOSIT_ID=$(echo $DEPOSIT_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('id', d.get('deposit',{}).get('id','')))" 2>/dev/null)

if [ -z "$DEPOSIT_ID" ]; then
  echo "Response: $DEPOSIT_RESPONSE"
  fail "Deposit failed"
fi
pass "Deposit created: $DEPOSIT_ID"

# 7. Get Portfolio
info "7. Checking portfolio balance..."
PORTFOLIO_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/portfolio" \
  -H "Authorization: Bearer $JWT_TOKEN")

BALANCE=$(echo $PORTFOLIO_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('available_balance', d.get('portfolio',{}).get('available_balance',0)))" 2>/dev/null)
pass "Portfolio balance: \$$BALANCE"

# 8. Place Buy Order (Orders Service)
info "8. Placing buy order: 10 AAPL @ \$175..."
ORDER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/orders" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: order-buy-$TIMESTAMP" \
  -d "{\"symbol\":\"AAPL\",\"direction\":\"buy\",\"order_type\":\"limit\",\"quantity\":10,\"price\":175.00,\"time_in_force\":\"DAY\"}")

ORDER_ID=$(echo $ORDER_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('order',{}).get('id', d.get('id','')))" 2>/dev/null)

if [ -z "$ORDER_ID" ]; then
  echo "Response: $ORDER_RESPONSE"
  fail "Place order failed"
fi
pass "Order placed: $ORDER_ID"

# 9. List Orders
info "9. Listing orders..."
ORDERS_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/orders" \
  -H "Authorization: Bearer $JWT_TOKEN")

ORDER_COUNT=$(echo $ORDERS_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('orders', d.get('data',[]))))" 2>/dev/null)
pass "Found $ORDER_COUNT order(s)"

# 10. Place Sell Order (to trigger matching)
info "10. Placing sell order: 5 AAPL @ \$150 (should match)..."
SELL_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/orders" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: order-sell-$TIMESTAMP" \
  -d "{\"symbol\":\"AAPL\",\"direction\":\"sell\",\"order_type\":\"limit\",\"quantity\":5,\"price\":150.00,\"time_in_force\":\"DAY\"}")

SELL_ORDER_ID=$(echo $SELL_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('order',{}).get('id', d.get('id','')))" 2>/dev/null)

if [ -z "$SELL_ORDER_ID" ]; then
  echo "Response: $SELL_RESPONSE"
  fail "Place sell order failed"
fi
pass "Sell order placed: $SELL_ORDER_ID"

# 11. Check Trades
info "11. Checking trades..."
sleep 2  # Wait for matching engine
TRADES_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/trades" \
  -H "Authorization: Bearer $JWT_TOKEN")

TRADE_COUNT=$(echo $TRADES_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('trades', d.get('data',[]))))" 2>/dev/null)
pass "Found $TRADE_COUNT trade(s)"

echo ""
echo "=========================================="
echo -e "${GREEN}All E2E tests passed successfully!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Client ID: $CLIENT_ID"
echo "  - Email: $EMAIL"
echo "  - Orders: $ORDER_COUNT"
echo "  - Trades: $TRADE_COUNT"
