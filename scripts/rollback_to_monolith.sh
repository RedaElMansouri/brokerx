#!/bin/bash
# ============================================================
# BrokerX - Rollback to Monolith Script
# ============================================================
# Ce script permet de revenir rapidement à l'architecture monolithique
# en cas de problème avec les microservices.
#
# Usage: ./scripts/rollback_to_monolith.sh [--force]
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       BrokerX - Rollback to Monolith Architecture          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Confirmation
if [[ "$FORCE" == false ]]; then
    echo -e "${YELLOW}⚠️  ATTENTION: Cette action va:${NC}"
    echo "   1. Arrêter tous les containers microservices"
    echo "   2. Démarrer l'architecture monolithique"
    echo "   3. Utiliser docker-compose.monolith.yml"
    echo ""
    read -p "Êtes-vous sûr de vouloir continuer? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Rollback annulé.${NC}"
        exit 1
    fi
fi

cd "$PROJECT_ROOT"

# Step 1: Stop microservices
echo ""
echo -e "${BLUE}[1/4] Arrêt des microservices...${NC}"
docker compose down -v 2>/dev/null || true
echo -e "${GREEN}✅ Microservices arrêtés${NC}"

# Step 2: Clean up microservices volumes
echo ""
echo -e "${BLUE}[2/4] Nettoyage des volumes microservices...${NC}"
docker volume rm brokerx_postgres_clients_data 2>/dev/null || true
docker volume rm brokerx_postgres_portfolios_data 2>/dev/null || true
docker volume rm brokerx_postgres_orders_data 2>/dev/null || true
echo -e "${GREEN}✅ Volumes nettoyés${NC}"

# Step 3: Start monolith
echo ""
echo -e "${BLUE}[3/4] Démarrage du monolithe...${NC}"
docker compose -f docker-compose.monolith.yml up -d
echo -e "${GREEN}✅ Monolithe démarré${NC}"

# Step 4: Wait for health check
echo ""
echo -e "${BLUE}[4/4] Vérification de la santé du monolithe...${NC}"
sleep 10

MAX_RETRIES=30
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -s -f http://localhost:3000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Monolithe opérationnel!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}   Attente... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    echo -e "${RED}❌ Le monolithe n'a pas démarré correctement.${NC}"
    echo -e "${YELLOW}   Vérifiez les logs: docker compose -f docker-compose.monolith.yml logs${NC}"
    exit 1
fi

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 ROLLBACK TERMINÉ AVEC SUCCÈS               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Application:${NC}  http://localhost:3000"
echo -e "  ${BLUE}MailHog:${NC}      http://localhost:8025"
echo -e "  ${BLUE}PostgreSQL:${NC}   localhost:5432"
echo ""
echo -e "  ${YELLOW}Pour revenir aux microservices:${NC}"
echo -e "  docker compose -f docker-compose.monolith.yml down"
echo -e "  docker compose up -d"
echo ""
