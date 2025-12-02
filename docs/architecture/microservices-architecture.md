# BrokerX Microservices Architecture

## Vue d'ensemble

BrokerX utilise une architecture microservices avec un pattern **Strangler Fig** pour migrer progressivement du monolith vers des services indépendants.

## Architecture

![Architecture Microservices](diagrams/Microservices_Architecture.png)

## Services

### Clients Service (Port 3001)

**Responsabilités:**
- Gestion des clients (CRUD)
- Authentification (login/logout)
- Multi-factor authentication (MFA)
- Vérification email
- Gestion des tokens JWT

**Routes principales:**
- `POST /api/v1/clients` - Registration
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/verify_mfa` - MFA verification
- `GET /api/v1/me` - Current user profile

**Base de données:** `clients_service_development` (PostgreSQL 5433)

---

### Portfolios Service (Port 3002)

**Responsabilités:**
- Gestion des portfolios clients
- Dépôts et retraits
- Calcul des balances
- Historique des transactions
- Réservation de fonds (inter-service)

**Routes principales:**
- `GET /api/v1/portfolios/:id` - Get portfolio
- `POST /api/v1/deposits` - Create deposit
- `GET /api/v1/deposits` - List deposits
- `POST /internal/reserve` - Reserve funds (internal)
- `POST /internal/release` - Release funds (internal)

**Base de données:** `portfolios_service_development` (PostgreSQL 5434)

---

### Orders Service (Port 3003)

**Responsabilités:**
- Création d'ordres (market, limit)
- Annulation d'ordres
- Modification d'ordres
- Données de marché en temps réel
- Exécutions et trades
- WebSocket pour mises à jour live

**Routes principales:**
- `POST /api/v1/orders` - Create order
- `GET /api/v1/orders/:id` - Get order
- `POST /api/v1/orders/:id/cancel` - Cancel order
- `POST /api/v1/orders/:id/replace` - Replace order
- `GET /api/v1/market_data` - Market data

**Base de données:** `orders_service_development` (PostgreSQL 5435)

---

## Kong Gateway

Kong Gateway agit comme point d'entrée unique (API Gateway) et implémente:

- **Rate Limiting**: 100 requêtes/minute par consommateur
- **Authentication**: API Keys pour les routes protégées
- **CORS**: Headers pour les applications web
- **Load Balancing**: Round-robin pour le service Orders
- **Prometheus Metrics**: Export des métriques pour monitoring

### Configuration

```yaml
# gateway/kong.yml
services:
  - name: clients
    url: http://clients-service:3000
    routes:
      - paths: [/api/v1/clients, /api/v1/auth, /api/v1/me]
  
  - name: portfolios
    url: http://portfolios:3000
    routes:
      - paths: [/api/v1/portfolio, /api/v1/deposits]
  
  - name: orders
    url: http://orders-upstream  # Load balanced
    routes:
      - paths: [/api/v1/orders]
```

---

## Strangler Fig Pattern

### Étapes de migration

1. ✅ **Step 1**: Identifier les bounded contexts (Clients, Portfolios, Orders)
2. ✅ **Step 2**: Créer les nouveaux microservices
3. ✅ **Step 3**: Configurer les bases de données séparées
4. ✅ **Step 4**: Implémenter les APIs dans les microservices
5. ✅ **Step 5**: Kong Gateway route le trafic vers les microservices
6. 🔄 **Step 6**: Supprimer le code monolith correspondant (optionnel)

### Fallback

Le monolith (port 3000) reste disponible comme fallback:
- Routes identiques pour toutes les fonctionnalités
- Utilise la base de données partagée originale
- Peut être utilisé en cas de problème avec les microservices

---

## Communication Inter-Services

### Synchrone (HTTP)

Les services communiquent via HTTP pour les opérations critiques:

```ruby
# Orders Service appelle Portfolios Service pour réserver des fonds
PortfoliosFacade.new.reserve_funds(
  client_id: client_id,
  amount: order_total
)
```

### Asynchrone (Outbox Pattern)

Pour les événements non-bloquants, on utilise le pattern Outbox:

1. L'opération est enregistrée dans la table `outbox_events`
2. Un worker récupère les événements périodiquement
3. Les événements sont publiés vers les autres services
4. Les services consomment et traitent les événements

---

## Déploiement

### Développement local

```bash
# Démarrer tous les microservices
docker compose -f docker-compose.microservices.yml up -d

# Démarrer le monolith (optionnel)
docker compose up -d

# Vérifier la santé
curl http://localhost:8080/health  # Kong
curl http://localhost:3001/health  # Clients
curl http://localhost:3002/health  # Portfolios
curl http://localhost:3003/health  # Orders
```

### Ports

| Service | Port | Description |
|---------|------|-------------|
| Kong Gateway | 8080 | API Gateway (HTTP) |
| Kong Admin | 8001 | Kong Admin API |
| Monolith | 3000 | Rails Monolith (fallback) |
| Clients | 3001 | Clients/Auth Service |
| Portfolios | 3002 | Portfolios Service |
| Orders | 3003 | Orders Service |
| PostgreSQL (main) | 5432 | Monolith DB |
| PostgreSQL (clients) | 5433 | Clients DB |
| PostgreSQL (portfolios) | 5434 | Portfolios DB |
| PostgreSQL (orders) | 5435 | Orders DB |
| Redis | 6379 | Cache & ActionCable |
| MailHog | 8025 | Email testing UI |

---

## Tests

### Test d'enregistrement via Kong

```bash
curl -X POST http://localhost:8080/api/v1/clients \
  -H "Content-Type: application/json" \
  -d '{"client":{"name":"Test","email":"test@example.com","password":"password123","password_confirmation":"password123"}}'
```

### Test de login via Kong

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## Monitoring

### Prometheus Metrics

Tous les services exposent des métriques Prometheus:
- `/metrics` - Métriques applicatives
- Kong exporte automatiquement les métriques de latence et status codes

### Grafana Dashboards

Dashboards disponibles:
- Service Health Overview
- Request Rate & Latency
- Error Rates by Service
- Database Connection Pools
