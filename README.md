# BrokerX

Welcome to BrokerX. This repository contains a Rails 7 API with a DDD-inspired structure (Domain, Application, Infrastructure).

## Documentation

- Phase 0 summary (RDoc): `docs/rdoc/P0_Report.rdoc`
- Environment & configuration (RDoc): `docs/rdoc/Environment.rdoc`
- Additional docs are under `docs/` (architecture, operations, DDD notes, testing, etc.).

## Getting started

See `docs/operations/runbook.md` for environment setup, running migrations, and starting the app.

## CI/CD

This repo includes a single GitHub Actions workflow for continuous integration and delivery:

- CI/CD: `.github/workflows/ci-cd.yml`
	- CI: Runs tests on PRs and pushes to `main` (Ruby 3.2.2, Postgres 15, `rails db:prepare`, then `rspec` or `rails test`). RuboCop runs non-blocking if available.
	- CD (SSH-based): On push events (not PRs), deploys over SSH to a server by copying the repo to `/opt/brokerx` and running `docker compose up -d --build` remotely using `docker-compose.yml`.
		- Requires repo secrets: `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY` (PEM). Optionally `DEPLOY_PATH` (defaults to `/opt/brokerx`).
		- Prerequisites on the server: Docker Engine and Docker Compose v2 (`docker compose`). Port 3000 exposed.
		- Note: The provided compose file is development-oriented (RAILS_ENV=development, mounts code). For production, consider a separate compose file with `RAILS_ENV=production`, secrets, and hardened settings.

### Deployment

The CI/CD workflow builds and publishes a Docker image to GHCR. No Docker Compose deployment is included in this project by design. If you later want automated deployment (e.g., to a VM or container platform), we can add an appropriate deploy job or provide environment-specific manifests.