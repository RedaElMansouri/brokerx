#!/bin/bash
# ============================================================
# BrokerX - Quick E2E Smoke Test
# ============================================================
# Test rapide pour vérifier que tous les services répondent.
#
# Usage: ./test/e2e/smoke_test.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 BrokerX - Smoke Test"
echo "========================"
echo ""

FAILED=0

# Test Clients Service
echo -n "Clients Service (3001)... "
if curl -s -f http://localhost:3001/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    FAILED=1
fi

# Test Portfolios Service  
echo -n "Portfolios Service (3002)... "
if curl -s -f http://localhost:3002/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    FAILED=1
fi

# Test Orders Service
echo -n "Orders Service (3003)... "
if curl -s -f http://localhost:3003/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    FAILED=1
fi

# Test Kong Gateway
echo -n "Kong Gateway (8080)... "
if curl -s http://localhost:8080/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    FAILED=1
fi

# Test Redis
echo -n "Redis (6379)... "
if docker exec brokerx-redis redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    FAILED=1
fi

echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All services are operational! ✅${NC}"
    exit 0
else
    echo -e "${RED}Some services are not responding. ❌${NC}"
    echo -e "${YELLOW}Run 'docker compose up -d' to start services.${NC}"
    exit 1
fi
