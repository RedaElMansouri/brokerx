# 📋 Plan d'Extraction des Microservices - Méthode Strangler Fig

## 🎯 Référence
Basé sur : [microservices.io - Example of extracting a service](https://microservices.io/refactoring/example-of-extracting-a-service.html)

---

## ⚠️ Contraintes du Projet

| Contrainte | Valeur |
|------------|--------|
| **Branche de travail** | `feature/microservices-extraction` |
| **Deadline** | **5 décembre 2025** |
| **Jours restants** | ~9 jours (26 nov → 5 déc) |
| **Source UC** | `docs/use_cases/UC01-UC08` |

---

## 📊 Mapping Use Cases Officiels → Services

### Use Cases du Cahier des Charges

| UC | Nom Officiel | Service Cible |
|----|--------------|---------------|
| **UC-01** | Inscription & Vérification d'identité | Clients Service |
| **UC-02** | Authentification & MFA | Clients Service |
| **UC-03** | Dépôt de fonds (idempotent) | Portfolios Service |
| **UC-04** | Données de marché temps réel | Orders Service |
| **UC-05** | Placement d'ordre | Orders Service |
| **UC-06** | Modifier / Annuler un ordre | Orders Service |
| **UC-07** | Appariement événementiel | Orders Service |
| **UC-08** | Confirmation & Notifications d'exécution | Orders Service |

### Vue d'ensemble

| Service | Use Cases | Port | Database |
|---------|-----------|------|----------|
| **Clients Service** | UC-01, UC-02 | 3001 | `clients_db` (:5433) |
| **Portfolios Service** | UC-03 | 3002 | `portfolios_db` (:5434) |
| **Orders Service** | UC-04, UC-05, UC-06, UC-07, UC-08 | 3003 | `orders_db` (:5435) |
| **Gateway (Kong)** | Routing, Auth, Rate Limit | 8080 | - |

### Détail par Use Case (Cahier des Charges)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLIENTS SERVICE (:3001)                              │
│                         docs/use_cases/UC01, UC02                           │
│                                                                              │
│  UC-01: Inscription & Vérification d'identité                               │
│         POST /api/v1/clients/register                                        │
│         GET  /api/v1/clients/verify?token=xxx                               │
│         → Créer compte, vérifier email, activer                             │
│         → Statut: Pending → Active                                          │
│                                                                              │
│  UC-02: Authentification & MFA                                              │
│         POST /api/v1/auth/login                                              │
│         POST /api/v1/auth/verify_mfa                                         │
│         → Login 2 étapes, générer JWT                                       │
│         → Détection brute force, logs sécurité                              │
│                                                                              │
│  Tables: clients, verification_tokens, mfa_codes, audit_logs                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                       PORTFOLIOS SERVICE (:3002)                             │
│                       docs/use_cases/UC03                                    │
│                                                                              │
│  UC-03: Dépôt de fonds (idempotent)                                         │
│         POST /api/v1/deposits                                                │
│         GET  /api/v1/deposits                                                │
│         GET  /api/v1/portfolio                                               │
│         → Dépôt avec Idempotency-Key                                        │
│         → Éviter doublons sur retry réseau                                  │
│                                                                              │
│  INTERNAL APIs (appelées par Orders Service):                                │
│         POST /internal/reserve   → Réserver fonds pour ordre                │
│         POST /internal/release   → Libérer fonds (compensation)             │
│         POST /internal/debit     → Débiter après exécution                  │
│                                                                              │
│  Tables: portfolios, transactions, positions, idempotency_keys              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         ORDERS SERVICE (:3003)                               │
│                         docs/use_cases/UC04, UC05, UC06, UC07, UC08         │
│                                                                              │
│  UC-04: Données de marché temps réel                                        │
│         WS /cable → MarketChannel                                           │
│         → Push quotes, orderbook via ActionCable                            │
│         → Mode throttled/normal                                             │
│                                                                              │
│  UC-05: Placement d'ordre                                                   │
│         POST /api/v1/orders                                                  │
│         → Valider, réserver fonds (via Portfolios), créer ordre            │
│         → Types: market, limit, stop                                        │
│         → TradingSaga orchestration                                         │
│                                                                              │
│  UC-06: Modifier / Annuler un ordre                                         │
│         POST /api/v1/orders/:id/replace                                      │
│         POST /api/v1/orders/:id/cancel                                       │
│         → Optimistic locking (lock_version)                                 │
│         → Libérer fonds sur annulation                                      │
│                                                                              │
│  UC-07: Appariement événementiel                                            │
│         INTERNAL - MatchingEngine                                           │
│         → Matcher buy/sell par prix/temps                                   │
│         → Publier events order.matched                                      │
│                                                                              │
│  UC-08: Confirmation & Notifications d'exécution                            │
│         WS /cable → OrdersChannel                                           │
│         → Push execution reports                                            │
│         → Email de confirmation                                             │
│                                                                              │
│  Tables: orders, executions, outbox_events                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Méthode d'Extraction : Strangler Fig (5 Steps)

Pour **chaque service**, on suit ces 5 étapes :

### Étape 0 : Analyser le code AS-IS

```
┌─────────────────────────────────────────────────────────────────┐
│                    MONOLITH ACTUEL                               │
│                                                                  │
│  app/                                                            │
│  ├── domain/                                                     │
│  │   ├── clients/        ←── À extraire vers Clients Service    │
│  │   ├── portfolios/     ←── À extraire vers Portfolios Service │
│  │   └── orders/         ←── À extraire vers Orders Service     │
│  ├── application/                                                │
│  │   ├── use_cases/                                              │
│  │   └── services/                                               │
│  └── infrastructure/                                             │
│                                                                  │
│  db/schema.rb            ←── Toutes les tables ensemble         │
└─────────────────────────────────────────────────────────────────┘
```

### Étape 1 : Split the Code (Module découplé dans le monolith)

```
┌─────────────────────────────────────────────────────────────────┐
│                    MONOLITH + MODULE                             │
│                                                                  │
│  app/                                                            │
│  ├── modules/                                                    │
│  │   └── clients/        ←── Module découplé avec façade        │
│  │       ├── facade.rb   ←── Interface publique                 │
│  │       ├── domain/                                             │
│  │       ├── application/                                        │
│  │       └── infrastructure/                                     │
│  └── ...                                                         │
│                                                                  │
│  Le reste du monolith appelle UNIQUEMENT la façade              │
└─────────────────────────────────────────────────────────────────┘
```

### Étape 2 : Split the Database

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASES SÉPARÉES                            │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  clients_db  │    │portfolios_db │    │  orders_db   │       │
│  │  :5433       │    │  :5434       │    │  :5435       │       │
│  │              │    │              │    │              │       │
│  │ - clients    │    │ - portfolios │    │ - orders     │       │
│  │ - mfa_codes  │    │ - transactions│   │ - executions │       │
│  │ - tokens     │    │ - positions  │    │ - outbox     │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│                                                                  │
│  Chaque module a son propre schema/connexion                    │
└─────────────────────────────────────────────────────────────────┘
```

### Étape 3 : Define Standalone Service (pas encore en production)

```
┌─────────────────────────────────────────────────────────────────┐
│                    SERVICE STANDALONE                            │
│                                                                  │
│  services/clients-service/                                       │
│  ├── app/                                                        │
│  │   ├── controllers/                                            │
│  │   ├── domain/                                                 │
│  │   └── ...                                                     │
│  ├── config/                                                     │
│  ├── db/                                                         │
│  ├── Dockerfile                                                  │
│  └── Gemfile                                                     │
│                                                                  │
│  Le service tourne mais ne reçoit PAS encore de trafic prod     │
└─────────────────────────────────────────────────────────────────┘
```

### Étape 4 : Route Traffic to Service

```
┌─────────────────────────────────────────────────────────────────┐
│                    GATEWAY ROUTING                               │
│                                                                  │
│                      ┌─────────────┐                            │
│   Client ──────────► │    Kong     │                            │
│                      │   Gateway   │                            │
│                      └──────┬──────┘                            │
│                             │                                    │
│         ┌───────────────────┼───────────────────┐               │
│         ▼                   ▼                   ▼               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Clients   │    │  Portfolios │    │   Orders    │         │
│  │   Service   │    │   Service   │    │   Service   │         │
│  │    :3001    │    │    :3002    │    │    :3003    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                  │
│  Le Gateway route vers les services au lieu du monolith        │
└─────────────────────────────────────────────────────────────────┘
```

### Étape 5 : Remove from Monolith

```
┌─────────────────────────────────────────────────────────────────┐
│                    MONOLITH ÉVIDÉ                                │
│                                                                  │
│  Le code clients/portfolios/orders est SUPPRIMÉ du monolith    │
│                                                                  │
│  Il ne reste que:                                                │
│  - Le frontend (peut devenir un service séparé)                 │
│  - Les assets statiques                                          │
│                                                                  │
│  Ou le monolith disparaît complètement                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Structure Cible

```
brokerx/
├── services/
│   ├── clients-service/           # UC-01, UC-02, UC-03
│   │   ├── app/
│   │   │   ├── controllers/
│   │   │   │   └── api/v1/
│   │   │   │       ├── clients_controller.rb
│   │   │   │       └── authentication_controller.rb
│   │   │   ├── domain/
│   │   │   │   └── clients/
│   │   │   │       ├── entities/
│   │   │   │       │   └── client.rb
│   │   │   │       └── value_objects/
│   │   │   │           ├── email.rb
│   │   │   │           └── password.rb
│   │   │   ├── application/
│   │   │   │   └── use_cases/
│   │   │   │       ├── register_client.rb
│   │   │   │       ├── verify_email.rb
│   │   │   │       └── authenticate_user.rb
│   │   │   └── infrastructure/
│   │   │       └── persistence/
│   │   ├── config/
│   │   │   ├── database.yml      # → clients_db
│   │   │   └── routes.rb
│   │   ├── db/
│   │   │   ├── migrate/
│   │   │   └── schema.rb
│   │   ├── Dockerfile
│   │   ├── Gemfile
│   │   └── README.md
│   │
│   ├── portfolios-service/        # UC-04, UC-05
│   │   ├── app/
│   │   │   ├── controllers/
│   │   │   │   └── api/v1/
│   │   │   │       ├── portfolios_controller.rb
│   │   │   │       └── deposits_controller.rb
│   │   │   ├── domain/
│   │   │   │   └── portfolios/
│   │   │   │       ├── entities/
│   │   │   │       │   └── portfolio.rb
│   │   │   │       └── value_objects/
│   │   │   │           └── money.rb
│   │   │   ├── application/
│   │   │   │   └── use_cases/
│   │   │   │       ├── get_portfolio.rb
│   │   │   │       ├── deposit_funds.rb
│   │   │   │       ├── reserve_funds.rb
│   │   │   │       └── release_funds.rb
│   │   │   └── infrastructure/
│   │   │       ├── persistence/
│   │   │       └── http_clients/
│   │   │           └── clients_service_client.rb  # Appel Clients Service
│   │   ├── config/
│   │   │   ├── database.yml      # → portfolios_db
│   │   │   └── routes.rb
│   │   ├── db/
│   │   ├── Dockerfile
│   │   └── Gemfile
│   │
│   ├── orders-service/            # UC-06, UC-07, UC-08, UC-09, UC-10
│   │   ├── app/
│   │   │   ├── controllers/
│   │   │   │   └── api/v1/
│   │   │   │       └── orders_controller.rb
│   │   │   ├── channels/
│   │   │   │   ├── market_channel.rb
│   │   │   │   └── orders_channel.rb
│   │   │   ├── domain/
│   │   │   │   └── orders/
│   │   │   │       ├── entities/
│   │   │   │       │   ├── order.rb
│   │   │   │       │   └── execution.rb
│   │   │   │       └── services/
│   │   │   │           └── matching_engine.rb
│   │   │   ├── application/
│   │   │   │   ├── use_cases/
│   │   │   │   │   ├── place_order.rb
│   │   │   │   │   ├── modify_order.rb
│   │   │   │   │   └── cancel_order.rb
│   │   │   │   └── sagas/
│   │   │   │       └── trading_saga.rb
│   │   │   └── infrastructure/
│   │   │       ├── persistence/
│   │   │       └── http_clients/
│   │   │           └── portfolios_service_client.rb  # Appel Portfolios
│   │   ├── config/
│   │   │   ├── database.yml      # → orders_db
│   │   │   └── routes.rb
│   │   ├── db/
│   │   ├── Dockerfile
│   │   └── Gemfile
│   │
│   └── gateway/                   # Kong configuration
│       └── kong.yml
│
├── docker-compose.microservices.yml
├── docs/
│   └── phase4/
│       ├── PLAN_MICROSERVICES_EXTRACTION.md  # Ce document
│       └── architecture/
│           └── microservices_diagram.puml
└── legacy/                        # Ancien monolith (référence)
    └── ...
```

---

## 🔗 Communication Inter-Services

### Synchrone (HTTP REST)

```
┌──────────────────┐         HTTP POST          ┌──────────────────┐
│  Orders Service  │ ─────────────────────────► │Portfolios Service│
│                  │  /internal/reserve         │                  │
│  place_order()   │  { client_id, amount }     │  reserve_funds() │
│                  │ ◄───────────────────────── │                  │
│                  │  { success: true }         │                  │
└──────────────────┘                            └──────────────────┘
```

### APIs Internes

| Service | Endpoint | Appelé par | Description |
|---------|----------|------------|-------------|
| Portfolios | `POST /internal/reserve` | Orders | Réserver fonds pour ordre |
| Portfolios | `POST /internal/release` | Orders | Libérer fonds (compensation) |
| Portfolios | `POST /internal/debit` | Orders | Débiter après exécution |
| Clients | `GET /internal/clients/:id` | Portfolios | Valider client existe |

---

## 🐳 Docker Compose Cible

```yaml
# docker-compose.microservices.yml
version: '3.8'

services:
  # ============ DATABASES ============
  postgres-clients:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: clients_db
      POSTGRES_USER: brokerx
      POSTGRES_PASSWORD: password
    ports:
      - "5433:5432"
    volumes:
      - clients_db_data:/var/lib/postgresql/data

  postgres-portfolios:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: portfolios_db
      POSTGRES_USER: brokerx
      POSTGRES_PASSWORD: password
    ports:
      - "5434:5432"
    volumes:
      - portfolios_db_data:/var/lib/postgresql/data

  postgres-orders:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: orders_db
      POSTGRES_USER: brokerx
      POSTGRES_PASSWORD: password
    ports:
      - "5435:5432"
    volumes:
      - orders_db_data:/var/lib/postgresql/data

  # ============ SERVICES ============
  clients-service:
    build: ./services/clients-service
    ports:
      - "3001:3000"
    environment:
      DATABASE_URL: postgres://brokerx:password@postgres-clients:5432/clients_db
      REDIS_URL: redis://redis:6379/1
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      - postgres-clients
      - redis

  portfolios-service:
    build: ./services/portfolios-service
    ports:
      - "3002:3000"
    environment:
      DATABASE_URL: postgres://brokerx:password@postgres-portfolios:5432/portfolios_db
      REDIS_URL: redis://redis:6379/2
      CLIENTS_SERVICE_URL: http://clients-service:3000
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      - postgres-portfolios
      - redis
      - clients-service

  orders-service:
    build: ./services/orders-service
    ports:
      - "3003:3000"
    environment:
      DATABASE_URL: postgres://brokerx:password@postgres-orders:5432/orders_db
      REDIS_URL: redis://redis:6379/3
      PORTFOLIOS_SERVICE_URL: http://portfolios-service:3000
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      - postgres-orders
      - redis
      - portfolios-service

  # ============ INFRASTRUCTURE ============
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  kong:
    image: kong:3.4-alpine
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yml
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
    volumes:
      - ./services/gateway/kong.yml:/etc/kong/kong.yml:ro
    ports:
      - "8080:8000"
      - "8443:8443"
      - "8001:8001"
    depends_on:
      - clients-service
      - portfolios-service
      - orders-service

  # ============ OBSERVABILITY ============
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/observability/prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3100:3000"

volumes:
  clients_db_data:
  portfolios_db_data:
  orders_db_data:
```

---

## 📅 Planning Accéléré (9 jours : 26 nov → 5 déc)

### 🚀 Jour 0 : Setup (26 novembre)

| Tâche | Durée | Description |
|-------|-------|-------------|
| 0.1 | 15 min | Créer branche `feature/microservices-extraction` |
| 0.2 | 30 min | Créer structure dossiers `services/` |
| 0.3 | 15 min | Créer `docker-compose.microservices.yml` de base |

```bash
git checkout -b feature/microservices-extraction
mkdir -p services/{clients-service,portfolios-service,orders-service,gateway}
```

### 📦 Jours 1-2 : Clients Service (27-28 novembre)

| Jour | Étape | Tâches |
|------|-------|--------|
| J1 AM | Step 0-1 | Analyser UC-01/UC-02, créer module découplé |
| J1 PM | Step 2 | Créer `clients_db`, migrer tables |
| J2 AM | Step 3 | Service standalone Rails API |
| J2 PM | Step 4-5 | Config Kong, tester isolation |

**Livrables:**
- [ ] `services/clients-service/` fonctionnel
- [ ] UC-01 (Register/Verify) via `:3001`
- [ ] UC-02 (Login/MFA) via `:3001`
- [ ] Database `clients_db` séparée

### 💰 Jours 3-4 : Portfolios Service (29-30 novembre)

| Jour | Étape | Tâches |
|------|-------|--------|
| J3 AM | Step 0-1 | Analyser UC-03, créer module |
| J3 PM | Step 2 | Créer `portfolios_db`, migrer tables |
| J4 AM | Step 3 | Service standalone + APIs internes |
| J4 PM | Step 4-5 | Kong routing, HTTP client → Clients |

**Livrables:**
- [ ] `services/portfolios-service/` fonctionnel
- [ ] UC-03 (Dépôt idempotent) via `:3002`
- [ ] APIs internes `/internal/reserve|release|debit`
- [ ] Database `portfolios_db` séparée

### 📈 Jours 5-7 : Orders Service (1-3 décembre)

| Jour | Étape | Tâches |
|------|-------|--------|
| J5 AM | Step 0-1 | Analyser UC-04/05/06/07/08, créer module |
| J5 PM | Step 2 | Créer `orders_db`, migrer tables |
| J6 AM | Step 3 | Service standalone + MatchingEngine |
| J6 PM | Step 3 | ActionCable (UC-04, UC-08) |
| J7 AM | Step 4 | Kong routing, HTTP client → Portfolios |
| J7 PM | Step 5 | TradingSaga avec appels HTTP |

**Livrables:**
- [ ] `services/orders-service/` fonctionnel
- [ ] UC-04 (WebSocket temps réel)
- [ ] UC-05 (Placement ordre)
- [ ] UC-06 (Modifier/Annuler)
- [ ] UC-07 (Matching Engine)
- [ ] UC-08 (Notifications)
- [ ] Database `orders_db` séparée

### 🔧 Jour 8 : Intégration & Tests (4 décembre)

| Tâche | Description |
|-------|-------------|
| 8.1 | Test flux complet : Register → Login → Deposit → Order |
| 8.2 | Tester compensation (Orders fail → release funds) |
| 8.3 | Vérifier isolation DB (3 databases distinctes) |
| 8.4 | Fix bugs critiques |
| 8.5 | Documenter l'architecture finale |

### 🚀 Jour 9 : Finalisation (5 décembre - DEADLINE)

| Tâche | Description |
|-------|-------------|
| 9.1 | Tests finaux |
| 9.2 | Merge PR ou présentation branche |
| 9.3 | Documentation README |
| 9.4 | **LIVRAISON** |

---

## 📊 Vue Timeline

```
Nov 26   Nov 27   Nov 28   Nov 29   Nov 30   Dec 1    Dec 2    Dec 3    Dec 4    Dec 5
  │        │        │        │        │        │        │        │        │        │
  ▼        ▼        ▼        ▼        ▼        ▼        ▼        ▼        ▼        ▼
┌────┐  ┌────────────────┐  ┌────────────────┐  ┌──────────────────────────┐  ┌────┐  ┌────┐
│SETUP│  │ CLIENTS SERVICE │  │PORTFOLIOS SERV.│  │    ORDERS SERVICE        │  │TEST│  │DONE│
│ J0 │  │   J1      J2    │  │   J3      J4   │  │  J5      J6      J7     │  │ J8 │  │ J9 │
└────┘  └────────────────┘  └────────────────┘  └──────────────────────────┘  └────┘  └────┘
         UC-01, UC-02         UC-03              UC-04,05,06,07,08            Intég   DEADLINE
```

---

## ✅ Critères de Succès

### Microservices
- [ ] Branche `feature/microservices-extraction` créée
- [ ] 3 services sur 3 ports différents (3001, 3002, 3003)
- [ ] 3 bases de données séparées (5433, 5434, 5435)
- [ ] Chaque service démarre indépendamment
- [ ] Communication HTTP entre services
- [ ] Gateway Kong route correctement

### Use Cases Fonctionnels (Cahier des Charges)
- [ ] UC-01 : Inscription & Vérification → Clients Service
- [ ] UC-02 : Authentification MFA → Clients Service
- [ ] UC-03 : Dépôt idempotent → Portfolios Service
- [ ] UC-04 : Données temps réel → Orders Service
- [ ] UC-05 : Placement ordre → Orders Service
- [ ] UC-06 : Modifier/Annuler → Orders Service
- [ ] UC-07 : Appariement → Orders Service
- [ ] UC-08 : Notifications → Orders Service

### Résilience
- [ ] Compensation fonctionne (si Orders fail → release funds)
- [ ] Chaque service a ses health checks
- [ ] Retry/timeout sur appels inter-services

---

## 🚀 Commandes de Démarrage

```bash
# 1. Créer la branche de travail
git checkout -b feature/microservices-extraction

# 2. Démarrer tous les microservices
docker compose -f docker-compose.microservices.yml up -d

# 3. Vérifier les services
docker compose -f docker-compose.microservices.yml ps

# 4. Logs d'un service spécifique
docker compose -f docker-compose.microservices.yml logs -f clients-service
```

---

## 🔮 Phase Suivante : Event-Driven (Post-Deadline)

Une fois les microservices livrés le 5 décembre, la prochaine itération sera :

1. **Ajouter Message Broker** (Redis Streams ou Kafka)
2. **Publier des Events** :
   - `client.registered` (UC-01)
   - `client.verified` (UC-01)
   - `deposit.completed` (UC-03)
   - `order.placed` (UC-05)
   - `order.matched` (UC-07)
   - `order.executed` (UC-08)
3. **Saga Chorégraphié** au lieu d'appels HTTP synchrones
4. **CQRS** pour séparation read/write

---

## 📝 Notes Importantes

1. **Travailler sur la branche `feature/microservices-extraction`** - Ne pas modifier `main`
2. **Commits fréquents** - Un commit par étape majeure
3. **Tester après chaque service** - Ne pas attendre la fin
4. **Priorité aux UC critiques** - UC-01, UC-02, UC-05 en premier

---

**Donne-moi le GO quand tu es prêt à commencer ! 🚀**
