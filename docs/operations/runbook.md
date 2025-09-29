# Runbook d’Exploitation — BrokerX+

Ce runbook décrit comment déployer, exploiter et dépanner l’application BrokerX+ en local et sur une VM via Docker/Compose, avec intégration CI GitHub Actions.

---

## 1. Architecture d’exécution
- Services principaux:
  - web (Rails API)
  - postgres (DB)
- Fichiers:
  - `Dockerfile`, `docker-compose.yml`
  - Pipelines CI: `.github/workflows/ci.yml` (proposé ci-dessous)

## 2. Prérequis
- Docker Desktop / Docker Engine + docker-compose
- Ruby/Bundler (pour dev local hors conteneur, optionnel)
- Accès au repo (read), variables d’env (si mailer/JWT custom)

## 3. Démarrage / Arrêt (Docker Compose)

Démarrage (build + migrations + serveur):
```powershell
# Windows PowerShell
docker compose up --build
```

Arrêt (garder volumes):
```powershell
docker compose down
```

Arrêt + purge volumes:
```powershell
docker compose down -v
```

Vérifier les logs:
```powershell
docker compose logs -f web
```

## 4. Santé & supervision
- Healthcheck applicatif: `http://localhost:3000/health`
- Logs applicatifs: `docker compose logs -f web`
- DB health: `docker compose logs postgres`
- (Phase 2) Métriques Prometheus: `http://localhost:9090/` (Prometheus), `http://localhost:3000/metrics` (exporter)
- (Phase 2) Grafana Dashboards: `http://localhost:3001/`

## 5. Base de données
- Création/migration (dans le conteneur):
```powershell
docker compose exec web rails db:create db:migrate
```
- Console Rails:
```powershell
docker compose exec web rails console
```
- Console psql:
```powershell
docker compose exec postgres psql -U brokerx -d brokerx_development
```

## 6. Opérations courantes
- Redémarrer l’app seulement:
```powershell
docker compose restart web
```
- Voir l’état des services:
```powershell
docker compose ps
```
- Ouvrir un shell dans web:
```powershell
docker compose exec web sh
```

## 7. Déploiement sur VM (compose)
- Copier repo + `.env` (si utilisé)
- Lancer `docker compose up -d --build`
- Exposer ports via firewall: 3000 (API), 5432 (DB si besoin interne), (Phase 2: 9090 Prometheus, 3001 Grafana)
- Configurer reverse proxy (Nginx/Traefik) pour TLS et CORS

## 8. CI — GitHub Actions (proposition)
Créer `.github/workflows/ci.yml`:
```yaml
name: CI
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: brokerx_test
          POSTGRES_USER: brokerx
          POSTGRES_PASSWORD: password
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U brokerx -d brokerx_test"
          --health-interval 10s --health-timeout 5s --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Configure database.yml for CI
        run: |
          cp config/database.yml config/database.yml.bak
          ruby -e "c=File.read('config/database.yml'); c=c.gsub(/database: .*/, 'database: brokerx_test'); c=c.gsub(/username: .*/, 'username: brokerx'); c=c.gsub(/password: .*/, 'password: password'); c=c.gsub(/host: .*/, 'host: localhost'); File.write('config/database.yml', c)"

      - name: Install dependencies
        run: bundle install --jobs 4 --retry 3

      - name: DB setup
        env:
          RAILS_ENV: test
        run: |
          bin/rails db:create
          bin/rails db:migrate

      - name: Run tests
        env:
          RAILS_ENV: test
        run: |
          bin/rails test

      - name: Upload coverage (optional)
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
```

## 9. Sécurité & secrets
- Ne pas committer de secrets (utiliser GitHub Secrets, variables repo/organization)
- JWT secret (Rails `secret_key_base`) géré via env/secret manager
- CORS autorisé seulement pour origines prévues


## 10. Playbooks d’incident
- API 5xx élevé: vérifier logs web, saturation CPU/RAM, connexions DB, erreurs applicatives ; rollback si déploiement récent
- DB indisponible: vérifier container postgres, healthcheck, disques; restaurer depuis backup le cas échéant
- Latence élevée: profiler endpoints, activer cache Redis sur endpoints coûteux, augmenter le pool de workers/instances
- Fuite mémoire: inspecter containers, redéployer; activer métriques mémoire + alertes

## 11. Sauvegarde & restauration (DB)
- Dump local (exécution dans postgres):
```powershell
docker compose exec postgres pg_dump -U brokerx -d brokerx_development -F c -f /tmp/backup.dump
```
- Restauration:
```powershell
docker compose exec postgres pg_restore -U brokerx -d brokerx_development /tmp/backup.dump
```

## 12. Références
- Arc42: `docs/architecture/arc42/arc42.md`
- 4+1 Views: `docs/architecture/4plus1_views/`
- Phase 1 / Phase 2: `docs/phase1_summary.md`, `docs/phase2/plan.md`
- Repository Pattern: `docs/persistance/repository_pattern.md`
