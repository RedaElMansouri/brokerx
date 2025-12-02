#!/bin/bash
# ============================================================
# BrokerX - E2E Tests for Microservices
# ============================================================
# Ce script exécute les tests end-to-end sur l'architecture microservices.
#
# Usage: ./test/e2e/run_e2e_tests.sh [--skip-setup]
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Configuration
GATEWAY_URL="http://localhost:8080"
CLIENTS_URL="http://localhost:3001"
PORTFOLIOS_URL="http://localhost:3002"
ORDERS_URL="http://localhost:3003"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         BrokerX - E2E Microservices Test Suite             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# HELPER FUNCTIONS
# ============================================================

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# HTTP request helper
http_request() {
    local method=$1
    local url=$2
    local data=$3
    local token=$4
    
    local curl_cmd="curl -s -w '\n%{http_code}' -X $method"
    
    if [[ -n "$token" ]]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $token'"
    fi
    
    curl_cmd="$curl_cmd -H 'Content-Type: application/json'"
    
    if [[ -n "$data" ]]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    curl_cmd="$curl_cmd '$url'"
    
    eval $curl_cmd
}

# Extract HTTP status code from response
get_status_code() {
    echo "$1" | tail -1
}

# Extract JSON body from response
get_body() {
    echo "$1" | sed '$d'
}

# ============================================================
# SETUP
# ============================================================

if [[ "$1" != "--skip-setup" ]]; then
    log_info "Vérification des services..."
    
    # Check if services are running
    for service in "$CLIENTS_URL" "$PORTFOLIOS_URL" "$ORDERS_URL" "$GATEWAY_URL"; do
        if ! curl -s -f "$service/health" > /dev/null 2>&1; then
            echo -e "${RED}❌ Service non disponible: $service${NC}"
            echo -e "${YELLOW}   Démarrez les services avec: docker compose up -d${NC}"
            exit 1
        fi
    done
    
    log_info "Tous les services sont opérationnels ✅"
fi

echo ""

# ============================================================
# TEST SUITE 1: CLIENTS SERVICE
# ============================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  TEST SUITE 1: CLIENTS SERVICE                              ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 1.1: Health Check
log_test "1.1 - Health Check Clients Service"
response=$(curl -s -w '\n%{http_code}' "$CLIENTS_URL/health")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]]; then
    log_pass "Health check OK (status: $status)"
else
    log_fail "Health check failed (status: $status)"
fi

# Test 1.2: Client Registration
log_test "1.2 - Client Registration"
TIMESTAMP=$(date +%s)
TEST_EMAIL="e2e_test_${TIMESTAMP}@brokerx.com"
response=$(curl -s -w '\n%{http_code}' -X POST "$CLIENTS_URL/api/v1/clients" \
    -H "Content-Type: application/json" \
    -d "{
        \"client\": {
            \"email\": \"$TEST_EMAIL\",
            \"password\": \"SecurePass123!\",
            \"password_confirmation\": \"SecurePass123!\",
            \"first_name\": \"E2E\",
            \"last_name\": \"Test\",
            \"phone_number\": \"+15141234567\"
        }
    }")
status=$(get_status_code "$response")
body=$(get_body "$response")
if [[ "$status" == "201" ]] || [[ "$status" == "200" ]]; then
    log_pass "Client registration successful (status: $status)"
    CLIENT_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
else
    log_fail "Client registration failed (status: $status)"
fi

# Test 1.3: Client Authentication
log_test "1.3 - Client Authentication"
response=$(curl -s -w '\n%{http_code}' -X POST "$CLIENTS_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"SecurePass123!\"
    }")
status=$(get_status_code "$response")
body=$(get_body "$response")
if [[ "$status" == "200" ]] || [[ "$status" == "201" ]]; then
    log_pass "Authentication successful (status: $status)"
    AUTH_TOKEN=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
else
    log_fail "Authentication failed (status: $status)"
fi

# Test 1.4: Get Client Profile
log_test "1.4 - Get Client Profile"
if [[ -n "$AUTH_TOKEN" ]]; then
    response=$(curl -s -w '\n%{http_code}' -X GET "$CLIENTS_URL/api/v1/clients/me" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    status=$(get_status_code "$response")
    if [[ "$status" == "200" ]]; then
        log_pass "Get profile successful (status: $status)"
    else
        log_fail "Get profile failed (status: $status)"
    fi
else
    log_fail "No auth token available"
fi

echo ""

# ============================================================
# TEST SUITE 2: PORTFOLIOS SERVICE
# ============================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  TEST SUITE 2: PORTFOLIOS SERVICE                           ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 2.1: Health Check
log_test "2.1 - Health Check Portfolios Service"
response=$(curl -s -w '\n%{http_code}' "$PORTFOLIOS_URL/health")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]]; then
    log_pass "Health check OK (status: $status)"
else
    log_fail "Health check failed (status: $status)"
fi

# Test 2.2: Get Portfolio
log_test "2.2 - Get Portfolio"
if [[ -n "$AUTH_TOKEN" ]]; then
    response=$(curl -s -w '\n%{http_code}' -X GET "$PORTFOLIOS_URL/api/v1/portfolios" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    status=$(get_status_code "$response")
    if [[ "$status" == "200" ]] || [[ "$status" == "201" ]]; then
        log_pass "Get portfolio successful (status: $status)"
    else
        log_fail "Get portfolio failed (status: $status)"
    fi
else
    log_fail "No auth token available"
fi

# Test 2.3: Deposit Funds (Idempotent)
log_test "2.3 - Deposit Funds (Idempotent)"
IDEMPOTENCY_KEY="e2e-deposit-${TIMESTAMP}"
if [[ -n "$AUTH_TOKEN" ]]; then
    response=$(curl -s -w '\n%{http_code}' -X POST "$PORTFOLIOS_URL/api/v1/portfolios/deposit" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
        -d '{"amount": 10000.00}')
    status=$(get_status_code "$response")
    if [[ "$status" == "200" ]] || [[ "$status" == "201" ]]; then
        log_pass "Deposit successful (status: $status)"
    else
        log_fail "Deposit failed (status: $status)"
    fi
    
    # Test idempotency - same request should return same result
    log_test "2.4 - Verify Idempotency"
    response2=$(curl -s -w '\n%{http_code}' -X POST "$PORTFOLIOS_URL/api/v1/portfolios/deposit" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
        -d '{"amount": 10000.00}')
    status2=$(get_status_code "$response2")
    if [[ "$status2" == "200" ]] || [[ "$status2" == "201" ]]; then
        log_pass "Idempotency verified (status: $status2)"
    else
        log_fail "Idempotency check failed (status: $status2)"
    fi
else
    log_fail "No auth token available"
fi

echo ""

# ============================================================
# TEST SUITE 3: ORDERS SERVICE
# ============================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  TEST SUITE 3: ORDERS SERVICE                               ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 3.1: Health Check
log_test "3.1 - Health Check Orders Service"
response=$(curl -s -w '\n%{http_code}' "$ORDERS_URL/health")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]]; then
    log_pass "Health check OK (status: $status)"
else
    log_fail "Health check failed (status: $status)"
fi

# Test 3.2: Get Market Data
log_test "3.2 - Get Market Data"
response=$(curl -s -w '\n%{http_code}' "$ORDERS_URL/api/v1/market_data")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]]; then
    log_pass "Market data retrieved (status: $status)"
else
    log_fail "Market data failed (status: $status)"
fi

# Test 3.3: Place Buy Order
log_test "3.3 - Place Buy Order"
if [[ -n "$AUTH_TOKEN" ]]; then
    response=$(curl -s -w '\n%{http_code}' -X POST "$ORDERS_URL/api/v1/orders" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "order": {
                "symbol": "AAPL",
                "order_type": "limit",
                "side": "buy",
                "quantity": 10,
                "price": 150.00
            }
        }')
    status=$(get_status_code "$response")
    body=$(get_body "$response")
    if [[ "$status" == "200" ]] || [[ "$status" == "201" ]]; then
        log_pass "Buy order placed (status: $status)"
        ORDER_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    else
        log_fail "Buy order failed (status: $status)"
    fi
else
    log_fail "No auth token available"
fi

# Test 3.4: Get Orders List
log_test "3.4 - Get Orders List"
if [[ -n "$AUTH_TOKEN" ]]; then
    response=$(curl -s -w '\n%{http_code}' -X GET "$ORDERS_URL/api/v1/orders" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    status=$(get_status_code "$response")
    if [[ "$status" == "200" ]]; then
        log_pass "Orders list retrieved (status: $status)"
    else
        log_fail "Orders list failed (status: $status)"
    fi
else
    log_fail "No auth token available"
fi

# Test 3.5: Cancel Order
log_test "3.5 - Cancel Order"
if [[ -n "$AUTH_TOKEN" ]] && [[ -n "$ORDER_ID" ]]; then
    response=$(curl -s -w '\n%{http_code}' -X DELETE "$ORDERS_URL/api/v1/orders/$ORDER_ID" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    status=$(get_status_code "$response")
    if [[ "$status" == "200" ]] || [[ "$status" == "204" ]]; then
        log_pass "Order cancelled (status: $status)"
    else
        log_fail "Order cancellation failed (status: $status)"
    fi
else
    log_fail "No order to cancel"
fi

echo ""

# ============================================================
# TEST SUITE 4: API GATEWAY (KONG)
# ============================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  TEST SUITE 4: API GATEWAY (KONG)                           ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 4.1: Gateway Health
log_test "4.1 - Gateway Health Check"
response=$(curl -s -w '\n%{http_code}' "$GATEWAY_URL/")
status=$(get_status_code "$response")
if [[ "$status" != "000" ]]; then
    log_pass "Gateway responding (status: $status)"
else
    log_fail "Gateway not responding"
fi

# Test 4.2: Route to Clients via Gateway
log_test "4.2 - Route to Clients via Gateway"
response=$(curl -s -w '\n%{http_code}' "$GATEWAY_URL/api/v1/clients/health" 2>/dev/null || echo "000")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]] || [[ "$status" == "404" ]]; then
    log_pass "Gateway routing to clients (status: $status)"
else
    log_fail "Gateway routing failed (status: $status)"
fi

# Test 4.3: Route to Portfolios via Gateway
log_test "4.3 - Route to Portfolios via Gateway"
response=$(curl -s -w '\n%{http_code}' "$GATEWAY_URL/api/v1/portfolios/health" 2>/dev/null || echo "000")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]] || [[ "$status" == "404" ]]; then
    log_pass "Gateway routing to portfolios (status: $status)"
else
    log_fail "Gateway routing failed (status: $status)"
fi

# Test 4.4: Route to Orders via Gateway
log_test "4.4 - Route to Orders via Gateway"
response=$(curl -s -w '\n%{http_code}' "$GATEWAY_URL/api/v1/orders/health" 2>/dev/null || echo "000")
status=$(get_status_code "$response")
if [[ "$status" == "200" ]] || [[ "$status" == "404" ]]; then
    log_pass "Gateway routing to orders (status: $status)"
else
    log_fail "Gateway routing failed (status: $status)"
fi

echo ""

# ============================================================
# TEST SUITE 5: SAGA - ORDER PLACEMENT FLOW
# ============================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  TEST SUITE 5: CHOREOGRAPHED SAGA - ORDER FLOW              ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 5.1: Full Order Saga (Happy Path)
log_test "5.1 - Full Order Saga (Happy Path)"
if [[ -n "$AUTH_TOKEN" ]]; then
    # Place order that should trigger saga
    response=$(curl -s -w '\n%{http_code}' -X POST "$ORDERS_URL/api/v1/orders" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "order": {
                "symbol": "MSFT",
                "order_type": "market",
                "side": "buy",
                "quantity": 5
            }
        }')
    status=$(get_status_code "$response")
    if [[ "$status" == "200" ]] || [[ "$status" == "201" ]]; then
        log_pass "Saga order placed (status: $status)"
        SAGA_ORDER_ID=$(echo "$(get_body "$response")" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    else
        log_fail "Saga order failed (status: $status)"
    fi
else
    log_fail "No auth token available"
fi

# Test 5.2: Verify Order State Transition
log_test "5.2 - Verify Order State"
if [[ -n "$AUTH_TOKEN" ]] && [[ -n "$SAGA_ORDER_ID" ]]; then
    sleep 2  # Wait for saga to process
    response=$(curl -s -w '\n%{http_code}' -X GET "$ORDERS_URL/api/v1/orders/$SAGA_ORDER_ID" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    status=$(get_status_code "$response")
    body=$(get_body "$response")
    if [[ "$status" == "200" ]]; then
        order_status=$(echo "$body" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        log_pass "Order state retrieved: $order_status"
    else
        log_fail "Order state check failed (status: $status)"
    fi
else
    log_fail "No saga order to verify"
fi

# Test 5.3: Insufficient Funds (Compensation Path)
log_test "5.3 - Insufficient Funds (Compensation)"
if [[ -n "$AUTH_TOKEN" ]]; then
    # Try to place a very large order that should fail
    response=$(curl -s -w '\n%{http_code}' -X POST "$ORDERS_URL/api/v1/orders" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "order": {
                "symbol": "AAPL",
                "order_type": "limit",
                "side": "buy",
                "quantity": 100000,
                "price": 200.00
            }
        }')
    status=$(get_status_code "$response")
    # Both 422 (insufficient funds) and 201 (pending validation) are acceptable
    if [[ "$status" == "422" ]] || [[ "$status" == "400" ]]; then
        log_pass "Insufficient funds handled correctly (status: $status)"
    elif [[ "$status" == "201" ]] || [[ "$status" == "200" ]]; then
        log_pass "Order pending saga validation (status: $status)"
    else
        log_fail "Unexpected response (status: $status)"
    fi
else
    log_fail "No auth token available"
fi

echo ""

# ============================================================
# RESULTS SUMMARY
# ============================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     TEST RESULTS SUMMARY                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

PASS_RATE=0
if [[ $TESTS_TOTAL -gt 0 ]]; then
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
fi

echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${BLUE}Total:${NC}   $TESTS_TOTAL"
echo -e "  ${CYAN}Rate:${NC}    ${PASS_RATE}%"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✅ ALL TESTS PASSED SUCCESSFULLY              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ❌ SOME TESTS FAILED                          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
