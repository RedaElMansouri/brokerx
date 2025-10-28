# BrokerX

[![CI/CD](https://github.com/RedaElMansouri/brokerx/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/RedaElMansouri/brokerx/actions/workflows/ci-cd.yml)

Bienvenue sur BrokerX. Ce dépôt contient une API Rails 7 avec une architecture inspirée DDD (Domaine, Application, Infrastructure).

## Documentation

- Synthèse Phase 0 (RDoc) : `docs/rdoc/P0_Report.rdoc`
- Environnement & configuration (RDoc) : `docs/rdoc/Environment.rdoc`
- Autres documents sous `docs/` (architecture, exploitation, DDD, tests, etc.).

## Prise en main

Voir `docs/operations/runbook.md` pour préparer l’environnement, exécuter les migrations et démarrer l’application.

### Démarrage rapide (local)

- Monolith (dev):
	- `docker compose up -d --build`
- Observabilité (Prometheus + Grafana):
	- `docker compose -f docker-compose.observability.yml up -d`
- Microservices + Gateway (Kong) + seed + healthchecks:
	- `docker compose -f docker-compose.yml -f docker-compose.gateway.yml up -d --build`

Swagger UI: http://localhost:3000/swagger.html
Health: http://localhost:3000/health (microservices: health on their own ports)

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

- Une spécification OpenAPI est publiée sous `public/openapi.yaml` et consultable via Swagger UI à l’URL suivante lorsque le serveur tourne:
	- http://localhost:3000/swagger.html
	- Bouton « Authorize » → saisir le JWT (Bearer) pour tester les endpoints protégés.

## Phase 2 — Reproductibilité (< 30 min)

Ce guide reproduit la démonstration (Kong + microservices + observabilité) en local/VM.

1) Cloner
```bash
git clone https://github.com/RedaElMansouri/brokerx.git
cd brokerx
```

2) Démarrer les stacks
```bash
docker compose -f docker-compose.yml -f docker-compose.gateway.yml -f docker-compose.observability.yml up -d
```
Attendre que les services soient healthy (`docker ps`).

3) Générer un JWT (utilisateur démo)
```bash
docker compose -f docker-compose.yml -f docker-compose.gateway.yml exec portfolios \
	bundle exec rails runner "rec=Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(email: 'demo@brokerx.local'); puts Application::UseCases::AuthenticateUserUseCase.new(Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new).send(:generate_jwt_token, rec.id)"
```
Copier le jeton affiché dans `$TOKEN`.

4) Lancer la charge (k6 via Docker)
- Via gateway (Kong)
```bash
docker run --rm --network brokerx_default -v "$PWD":/scripts -w /scripts grafana/k6 run load/k6/gateway_smoke.js \
	-e BASE_URL=http://kong:8080 -e APIKEY=brokerx-key-123 -e TOKEN=$TOKEN -e VUS=5 -e DURATION=45s
```
- Direct vers services
```bash
docker run --rm --network brokerx_default -v "$PWD":/scripts -w /scripts grafana/k6 run load/k6/direct_microservices_smoke.js \
	-e PORTFOLIOS_URL=http://portfolios:3000 -e ORDERS_URL=http://orders-a:3000 -e TOKEN=$TOKEN -e VUS=5 -e DURATION=45s
```
- Optionnel : connexions WS (ActionCable) pour captures
```bash
docker run --rm --name k6-ws --network brokerx_default -v "$PWD":/scripts -w /scripts grafana/k6 run load/k6/cable_connect.js \
	-e WS_URL=ws://portfolios:3000/cable -e TOKEN=$TOKEN -e VUS=5 -e DURATION=5m -e WS_HOLD_MS=290000
```

5) Dashboards & captures
- Grafana : http://localhost:3001 → importer `docs/observability/grafana/brokerx-dashboard.json` et `docs/observability/grafana/kong-gateway-dashboard.json`
- Prometheus : http://localhost:9090 → vérifier `/targets` et la requête p95
- Voir les noms d’images attendus dans `docs/operations/screenshots.md`

6) Dépannage
- Panneaux vides : redémarrer Prometheus, relancer la charge
- Jauge WS à 0 : garder le run WS actif pendant les captures

## CI/CD

Ce dépôt inclut un unique workflow GitHub Actions pour l’intégration et la livraison continues :

- CI/CD : `.github/workflows/ci-cd.yml`
	- Build : construction de l’image Docker (multi‑étages) et upload comme artefact
	- Tests : unitaires/intégration/E2E (Rails test) avec publication du rapport de couverture
	- Qualité API : lint/validation OpenAPI de `public/openapi.yaml` (la pipeline échoue si la spec est invalide)
	- CD (via SSH) : lors d’un push (hors PR), déploie sur une VM en copiant le dépôt vers `/opt/brokerx`, en sauvegardant la version précédente puis en lançant `docker compose up -d --build`.
		- Secrets requis : `SSH_HOST`, `SSH_USER`, `SSH_PASSWORD`.
		- Prérequis côté VM : Docker Engine et Docker Compose v2 (`docker compose`). Port 3000 exposé.
		- Remarque : le `docker-compose.yml` fourni est orienté développement (RAILS_ENV=development, montages). Pour la prod, prévoir un fichier dédié avec `RAILS_ENV=production`, secrets et durcissements.

### Déploiement

- En un clic via GitHub Actions : un push sur `main` déclenche les tests puis le déploiement SSH.
- Scripts locaux : voir `scripts/deploy_vm.sh` et `scripts/rollback_vm.sh`.

Reproductibilité: déploiement complet sur VM en < 30 minutes (pipeline CI + script SSH/compose). Voir `docs/operations/runbook.md`.

Rollback : le workflow crée une sauvegarde datée sur la VM (ex : `/opt/brokerx_backup_YYYYmmddHHMMSS.tgz`). Utiliser le script de rollback pour restaurer.

## Qualité, tests et sécurité

- Pyramide de tests :
	- Unitaires : services applicatifs (ex : `OrderValidationService`).
	- Intégration : endpoints API (contrôleurs) avec base de données.
	- E2E : scénario clé bout‑en‑bout (ex : dépôt + ordre d’achat).

- Couverture ciblée :
	- SimpleCov est activé dans `test/test_helper.rb` avec un groupe « Critical » (application/services, contrôleurs API).
	- Gate : échec du pipeline si la couverture du groupe « Critical » < 80% (seuil configurable via `CRITICAL_MIN_COVERAGE`).

- E2E minimal :
	- `test/integration/e2e_orders_flow_test.rb` : place un ordre d’achat (market) via l’API avec JWT valide.

- Sécurité de base :
	- Gestion d’erreurs JSON uniformisée via `ApplicationController` (`code`, `message`, statuts HTTP standard).
	- Validation/assainissement d’entrées : strong params (`order_params`) dans `OrdersController`.
	- Logs d’accès structurés (JSON) activables via Lograge (`config/initializers/lograge.rb`).
	- Secrets : pas de secrets en clair dans le code ; utiliser des variables d’environnement (ex : `SECRET_KEY_BASE`).