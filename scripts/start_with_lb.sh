#!/bin/bash
# ============================================================
# BrokerX - Start with Load Balancing
# ============================================================
# Démarre les microservices avec plusieurs réplicas et Nginx LB
#
# Usage: ./scripts/start_with_lb.sh [--build]
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     BrokerX - Microservices with Load Balancing            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd "$PROJECT_ROOT"

# Check for --build flag
BUILD_FLAG=""
if [[ "$1" == "--build" ]]; then
    BUILD_FLAG="--build"
    echo -e "${YELLOW}Building images...${NC}"
fi

# Start services
echo -e "${BLUE}[1/3] Démarrage des services avec load balancing...${NC}"
docker compose -f docker-compose.yml -f docker-compose.lb.yml up -d $BUILD_FLAG

# Wait for services
echo -e "${BLUE}[2/3] Attente que les services soient healthy...${NC}"
sleep 30

# Show status
echo -e "${BLUE}[3/3] Statut des services:${NC}"
docker compose -f docker-compose.yml -f docker-compose.lb.yml ps

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              LOAD BALANCING ACTIVÉ                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}API Gateway (Kong):${NC}     http://localhost:8080"
echo -e "  ${BLUE}Nginx LB Status:${NC}        http://localhost:8081/nginx-status"
echo ""
echo -e "  ${YELLOW}Instances:${NC}"
echo -e "    - Clients:    2 instances (clients-1, clients-2)"
echo -e "    - Portfolios: 2 instances (portfolios-1, portfolios-2)"
echo -e "    - Orders:     3 instances (orders-1, orders-2, orders-3)"
echo ""
echo -e "  ${YELLOW}Vérifier le load balancing:${NC}"
echo -e "    curl -s http://localhost:8080/api/v1/orders/health | jq '.instance_id'"
echo ""
