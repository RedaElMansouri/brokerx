# BrokerX

[![CI/CD](https://github.com/RedaElMansouri/brokerx/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/RedaElMansouri/brokerx/actions/workflows/ci-cd.yml)

Bienvenue sur BrokerX. Ce dépôt contient une API Rails 7 avec une architecture inspirée DDD (Domaine, Application, Infrastructure).

## Documentation

- Synthèse Phase 0 (RDoc) : `docs/rdoc/P0_Report.rdoc`
- Environnement & configuration (RDoc) : `docs/rdoc/Environment.rdoc`
- Autres documents sous `docs/` (architecture, exploitation, DDD, tests, etc.).

## Prise en main

Voir `docs/operations/runbook.md` pour préparer l’environnement, exécuter les migrations et démarrer l’application.

### Documentation API (Swagger)

- Une spécification OpenAPI est publiée sous `public/openapi.yaml` et consultable via Swagger UI à l’URL suivante lorsque le serveur tourne:
	- http://localhost:3000/swagger.html
	- Bouton « Authorize » → saisir le JWT (Bearer) pour tester les endpoints protégés.

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