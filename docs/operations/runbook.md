## Déploiement (VM)

Prérequis : Docker Engine + Docker Compose v2 sur la VM, port 3000 ouvert, accès SSH.

### En un clic via GitHub Actions

- Pousser sur `main` ou déclencher manuellement. La pipeline exécute : Lint → Build → Tests → Deploy (SSH).
- Le déploiement sauvegarde `/opt/brokerx` vers `/opt/brokerx_backup_YYYYmmddHHMMSS.tgz`, copie le dépôt puis lance `docker compose up -d --build`.

### Scripts locaux

- Déployer :
  - `SSH_HOST=... SSH_USER=... SSH_PASSWORD=... ./scripts/deploy_vm.sh`
  - Ou avec clé : `SSH_KEY=~/.ssh/id_rsa`

- Rollback :
  - Identifier l’archive de sauvegarde sur la VM (ex : `/opt/brokerx_backup_20250101123456.tgz`).
  - `SSH_HOST=... SSH_USER=... SSH_PASSWORD=... BACKUP=/opt/brokerx_backup_20250101123456.tgz ./scripts/rollback_vm.sh`

Notes :
- Le `docker-compose.yml` fourni est orienté développement (montages, RAILS_ENV=development). Pour la production, créer un `docker-compose.prod.yml` avec `RAILS_ENV=production`, secrets, volumes et healthchecks adaptés.
- L’endpoint de santé est disponible sur `/health`.
- Documentation API (Swagger) locale : `http://localhost:3000/swagger.html` (utiliser « Authorize » pour saisir le JWT Bearer).
# Runbook d’Exploitation — BrokerX+

Ce runbook décrit comment déployer, exploiter et dépanner l’application BrokerX+ en local et sur une VM via Docker/Compose, avec intégration CI GitHub Actions.

---

## 1. Architecture d’exécution
- Services principaux :
  - web (API Rails)
  - postgres (base de données)
- Fichiers :
  - `Dockerfile`, `docker-compose.yml`
  - Pipeline CI : `.github/workflows/ci-cd.yml`

## 2. Prérequis
- Docker Desktop / Docker Engine + docker compose
- Ruby/Bundler (optionnel pour dev hors conteneur)
- Accès au dépôt, variables d’env (mailer/JWT si nécessaire)

## 3. Démarrage / Arrêt (Docker Compose)

Démarrer (build + setup DB + serveur) :
```bash
docker compose up --build
```

Arrêter (conserver les volumes) :
```bash
docker compose down
```

Arrêter + purger les volumes :
```bash
docker compose down -v
```

Logs :
```bash
docker compose logs -f web
```

## 4. Santé & supervision
- Healthcheck applicatif : `http://localhost:3000/health`
- Logs applicatifs : `docker compose logs -f web`
- Santé DB : `docker compose logs postgres`
- (Phase 2) Prometheus : `http://localhost:9090/` ; Exporter : `http://localhost:3000/metrics`
- (Phase 2) Grafana : `http://localhost:3001/`

### Temps réel (ActionCable)
- WebSocket: `/cable` (auth via `?token=JWT`)
- En dev, la page Ordres utilise ActionCable si disponible, sinon un fallback WebSocket brut.
- Symptômes & correctifs:
  - Bloqué sur « initialisation »: CDN bloqué ou ActionCable non chargé → le fallback WS s’active automatiquement.
  - « rejeté (JWT manquant/invalide) »: vérifier l’origin et le jeton (généré à l’auth); se connecter dans la même origine.
  - Déconnexions fréquentes: vérifier l’onglet réseau WS, coupes réseau locales, ou throttling côté navigateur.

## 5. Base de données
- Création/migration (dans le conteneur) :
```bash
docker compose exec web rails db:create db:migrate
```
- Console Rails :
```bash
docker compose exec web rails console
```
- Console psql :
```bash
docker compose exec postgres psql -U brokerx -d brokerx_development
```

## 6. Opérations courantes
- Redémarrer l’app seulement :
```bash
docker compose restart web
```
- Voir l’état des services :
```bash
docker compose ps
```
- Ouvrir un shell dans web :
```bash
docker compose exec web sh
```

## 7. Déploiement sur VM (compose)
- Copier le dépôt + `.env` (si utilisé)
- Lancer `docker compose up -d --build`
- Ouvrir les ports via le pare-feu : 3000 (API), 5432 (DB interne), (Phase 2 : 9090 Prometheus, 3001 Grafana)
- Configurer un reverse proxy (Nginx/Traefik) pour TLS et CORS

## 8. Intégration Continue — GitHub Actions
Pipeline : `.github/workflows/ci-cd.yml`
```yaml
name: CI/CD
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

      - name: Install dependencies
        run: bundle install --jobs 4 --retry 3

      - name: DB setup
        env:
          RAILS_ENV: test
        run: |
          bundle exec rails db:create
          bundle exec rails db:migrate

      - name: Run tests
        env:
          RAILS_ENV: test
        run: |
          bundle exec rails test
          # Pour exécuter un sous-ensemble en local sans bloquer sur la couverture :
          # CRITICAL_MIN_COVERAGE=0 bundle exec rails test test/integration/uc06_order_modify_cancel_test.rb

      - name: Upload coverage (optionnel)
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
```

## 9. Sécurité & secrets
- Ne pas committer de secrets (utiliser GitHub Secrets/variables)
- Secret JWT (`secret_key_base`) géré via env/secret manager
- CORS autoriser uniquement les origines prévues


## 10. Playbooks d’incident
- Beaucoup de 5xx : vérifier logs web, CPU/RAM, connexions DB, erreurs applicatives ; rollback si déploiement récent
- DB indisponible : vérifier le conteneur postgres, healthcheck, disques ; restaurer depuis une sauvegarde si besoin
- Latence élevée : profiler les endpoints, activer un cache (Redis) sur les endpoints coûteux, augmenter le pool
- Fuite mémoire : inspecter les conteneurs, redéployer ; activer métriques et alertes

## 11. Sauvegarde & restauration (DB)
- Dump local (exécuté dans postgres) :
```bash
docker compose exec postgres pg_dump -U brokerx -d brokerx_development -F c -f /tmp/backup.dump
```
- Restauration :
```bash
docker compose exec postgres pg_restore -U brokerx -d brokerx_development /tmp/backup.dump
```

## 12. Références
- Arc42 : `docs/architecture/arc42/arc42.md`
- 4+1 Views : `docs/architecture/4plus1_views/`
- Phase 1 / Phase 2 : `docs/phase1_summary.md`, `docs/phase2/plan.md`
- Repository Pattern : `docs/persistance/repository_pattern.md`
