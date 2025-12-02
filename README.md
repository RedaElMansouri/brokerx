# BrokerX

[![CI/CD](https://github.com/RedaElMansouri/brokerx/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/RedaElMansouri/brokerx/actions/workflows/ci-cd.yml)

Bienvenue sur BrokerX. Ce dépôt contient une API Rails 7 avec une architecture inspirée DDD (Domaine, Application, Infrastructure).

## 🏗️ Architecture

> **⚠️ IMPORTANT**: Le monolithe (`app/`) est maintenant **DÉPRÉCIÉ**.  
> L'architecture active est basée sur les **microservices** (`services/`).

| Architecture | Docker Compose | Statut |
|--------------|----------------|--------|
| **Microservices** | `docker-compose.yml` | ✅ Active |
| Monolithe | `docker-compose.monolith.yml` | ⚠️ Déprécié |

### Services Microservices

| Service | Port | Description |
|---------|------|-------------|
| `clients-service` | 3001 | Gestion des clients, authentification |
| `portfolios-service` | 3002 | Portefeuilles, dépôts, fonds |
| `orders-service` | 3003 | Ordres, appariement, saga |
| `kong` | 8080 | API Gateway |

## Documentation

- Synthèse Phase 0 (RDoc) : `docs/rdoc/P0_Report.rdoc`
- Environnement & configuration (RDoc) : `docs/rdoc/Environment.rdoc`
- Autres documents sous `docs/` (architecture, exploitation, DDD, tests, etc.).

## Prise en main

Voir `docs/operations/runbook.md` pour préparer l'environnement, exécuter les migrations et démarrer l'application.

### Démarrage rapide (Microservices - Recommandé)

```bash
# Démarrer tous les microservices
docker compose up -d

# Vérifier que tout est opérationnel
./test/e2e/smoke_test.sh

# Voir les logs
docker compose logs -f
```

**Ports:**
- Kong Gateway: http://localhost:8080
- Clients: http://localhost:3001
- Portfolios: http://localhost:3002
- Orders: http://localhost:3003
- MailHog: http://localhost:8025

### Démarrage Monolithe (Déprécié)

```bash
# ⚠️ Utiliser uniquement pour rollback
docker compose -f docker-compose.monolith.yml up -d
```

### Rollback vers le Monolithe

En cas de problème avec les microservices:

```bash
./scripts/rollback_to_monolith.sh
```

### Observabilité

```bash
# Avec Prometheus + Grafana
docker compose --profile observability up -d

# Grafana: http://localhost:3004
# Prometheus: http://localhost:9090
```

### Tests E2E (Microservices)

```bash
# Smoke test rapide
./test/e2e/smoke_test.sh

# Suite E2E complète
./test/e2e/run_e2e_tests.sh

# Tests Rails
bundle exec rails test test/e2e/
```

### k6 (smoke via gateway)

```
k6 run load/k6/gateway_smoke.js \
  -e BASE_URL=http://localhost:8080 \
  -e APIKEY=brokerx-key-123 \
  -e TOKEN=<JWT>
```

### Endpoints principaux (API v1)

- Auth: `POST /api/v1/auth/login`, `POST /api/v1/auth/verify_mfa`
- Clients: `POST /api/v1/clients/register`, `GET /api/v1/clients/verify`
- Portefeuille: `GET /api/v1/portfolio`
- Dépôts: `POST /api/v1/deposits`, `GET /api/v1/deposits`
- Ordres: `POST /api/v1/orders`, `GET /api/v1/orders/:id`, `POST /api/v1/orders/:id/replace`, `POST /api/v1/orders/:id/cancel`, `DELETE /api/v1/orders/:id`

### Documentation API (Swagger)

- Une spécification OpenAPI est publiée sous `public/openapi.yaml` et consultable via Swagger UI à l'URL suivante lorsque le serveur tourne:
  - http://localhost:3000/swagger.html
  - Bouton « Authorize » → saisir le JWT (Bearer) pour tester les endpoints protégés.

## Phase 3 — Architecture Microservices

### Saga Chorégraphiée (UC-07)

L'appariement des ordres utilise une saga chorégraphiée:

1. **OrderCreated** → Orders Service
2. **FundsReservationRequested** → Portfolios Service
3. **FundsReserved** → Orders Service (matching)
4. **OrderMatched** → Notification

En cas d'échec, compensation automatique:
- **FundsReservationFailed** → Order rejected
- **OrderCancelled** → Funds released

### Structure des Microservices

```
services/
├── clients-service/     # Gestion des clients
├── portfolios-service/  # Portefeuilles et fonds
├── orders-service/      # Ordres et saga
├── gateway/             # Kong configuration
└── shared/              # EventBus, Outbox
```

## CI/CD

Ce dépôt inclut un unique workflow GitHub Actions pour l'intégration et la livraison continues :

- CI/CD : `.github/workflows/ci-cd.yml`
  - Build : construction de l'image Docker (multi‑étages) et upload comme artefact
  - Tests : unitaires/intégration/E2E (Rails test) avec publication du rapport de couverture
  - Qualité API : lint/validation OpenAPI de `public/openapi.yaml` (la pipeline échoue si la spec est invalide)
  - CD (via SSH) : lors d'un push (hors PR), déploie sur une VM en copiant le dépôt vers `/opt/brokerx`, en sauvegardant la version précédente puis en lançant `docker compose up -d --build`.
    - Secrets requis : `SSH_HOST`, `SSH_USER`, `SSH_PASSWORD`.
    - Prérequis côté VM : Docker Engine et Docker Compose v2 (`docker compose`). Port 3000 exposé.
    - Remarque : le `docker-compose.yml` fourni est orienté développement (RAILS_ENV=development, montages). Pour la prod, prévoir un fichier dédié avec `RAILS_ENV=production`, secrets et durcissements.

### Déploiement

- En un clic via GitHub Actions : un push sur `main` déclenche les tests puis le déploiement SSH.
- Scripts locaux : voir `scripts/deploy_vm.sh` et `scripts/rollback_vm.sh`.

Reproductibilité: déploiement complet sur VM en < 30 minutes (pipeline CI + script SSH/compose). Voir `docs/operations/runbook.md`.

Rollback : le workflow crée une sauvegarde datée sur la VM (ex : `/opt/brokerx_backup_YYYYmmddHHMMSS.tgz`). Utiliser le script de rollback pour restaurer.

## Qualité, tests et sécurité

- Pyramide de tests :
  - Unitaires : services applicatifs (ex : `OrderValidationService`).
  - Intégration : endpoints API (contrôleurs) avec base de données.
  - E2E : scénario clé bout‑en‑bout (ex : dépôt + ordre d'achat).

- Couverture ciblée :
  - SimpleCov est activé dans `test/test_helper.rb` avec un groupe « Critical » (application/services, contrôleurs API).
  - Gate : échec du pipeline si la couverture du groupe « Critical » < 80% (seuil configurable via `CRITICAL_MIN_COVERAGE`).

- E2E minimal :
  - `test/integration/e2e_orders_flow_test.rb` : place un ordre d'achat (market) via l'API avec JWT valide.
  - `test/e2e/microservices_e2e_test.rb` : tests complets des microservices.

- Sécurité de base :
  - Gestion d'erreurs JSON uniformisée via `ApplicationController` (`code`, `message`, statuts HTTP standard).
  - Validation/assainissement d'entrées : strong params (`order_params`) dans `OrdersController`.
  - Logs d'accès structurés (JSON) activables via Lograge (`config/initializers/lograge.rb`).
  - Secrets : pas de secrets en clair dans le code ; utiliser des variables d'environnement (ex : `SECRET_KEY_BASE`).
