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

- Unified CI/CD: `.github/workflows/ci-cd.yml` runs tests on PRs/pushes to `main`, and builds/pushes a Docker image to GHCR on pushes to `main` and version tags (`v*.*.*`).
	- Tests: Sets up Ruby 3.2.2, boots a Postgres 15 service, prepares the test DB, and runs tests (`rspec` if `spec/` exists, otherwise `rails test`). RuboCop runs non-blocking if available.
	- Image: `ghcr.io/<owner>/<repo>:<tag>` (e.g., `ghcr.io/OWNER/brokerx:latest`). Uses the built-in `GITHUB_TOKEN` with `packages: write` permission.

### Using the image with docker-compose

Deploy using `docker-compose.ghcr.yml`, which expects the `IMAGE` and `SECRET_KEY_BASE` env vars:

1) Generate a secret key (once) and store it securely as an environment variable (or secret in your platform):

```bash
# optional, run locally to generate a new secret
rails secret
```

2) On your server or local machine with Docker:

```bash
export IMAGE="ghcr.io/<owner>/brokerx:latest" # or a specific tag
export SECRET_KEY_BASE="<your-generated-secret>"
docker compose -f docker-compose.ghcr.yml up -d
```

If you run this on a remote host, make sure it can pull from `ghcr.io`. For private repos, authenticate with GHCR using a Personal Access Token that has `read:packages` scope.

### Optional remote deploy via SSH

You can extend `cd.yml` with a deploy job that SSHes into a server and runs `docker compose pull && up -d`. This requires the following GitHub Secrets:

- `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY` (PEM contents)
- Optionally `REMOTE_COMPOSE_FILE` (path on the server, default could be `/opt/brokerx/docker-compose.ghcr.yml`)

Reach out if you want this wired up; we can add a guarded deploy step that only runs when those secrets are present.