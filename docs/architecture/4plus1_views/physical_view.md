# Vue Physique (Déploiement) - 4+1 Views

## Objectif
Décrire l'architecture de déploiement, la topologie réseau, et les dépendances infrastructure.

## Architecture de Déploiement Phase 1

### Diagramme d'Architecture
  ![Diagram_architect](../assets/diagram_architect.png)

### Configuration Docker
```dockerfile
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - redis
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/brokerx
      - REDIS_URL=redis://redis:6379

  postgres:
    image: postgres:14
    environment:
      - POSTGRES_DB=brokerx
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  sidekiq:
    build: .
    command: bundle exec sidekiq -C config/sidekiq.yml
    depends_on:
      - redis
      - postgres

volumes:
  postgres_data:
  redis_data:
```

### Spécifications Infrastructure
#### Requirements Locaux (Développement)
```yaml
Minimum System Requirements:
  OS: macOS 12+ / Ubuntu 20.04+ / Windows 10+
  CPU: 4 cores
  RAM: 8GB
  Storage: 10GB libre
  Docker: 20.10+
  Docker Compose: 2.0+

Recommended:
  CPU: 8 cores
  RAM: 16GB
  Storage: SSD
```

#### Requirements Production (VM)
```yaml 
VM Specifications:
  OS: Ubuntu 22.04 LTS
  vCPUs: 4
  RAM: 8GB
  Storage: 50GB SSD
  Network: 1Gbps

Software Stack:
  Docker: 24.0+
  Docker Compose: 2.20+
  PostgreSQL: 14+
  Redis: 7+
```
### Configuration Réseau
#### Ports et Protocoles
```yaml 
Ports Exposés:
  - 3000: Application Rails (HTTP)
  - 5432: PostgreSQL (Database)
  - 6379: Redis (Cache)
  - 9090: Metrics (Prometheus - Phase 2)

Sécurité:
  - HTTPS via reverse proxy (nginx)
  - Firewall: ports 80/443 uniquement
  - VPN pour accès administration
```
#### Stratégie de Sauvegarde
```ruby
# config/backup.yml
backup:
  database:
    postgresql:
      host: localhost
      port: 5432
      database: brokerx
  storage:
    local:
      path: /backups
  schedules:
    daily: "0 2 * * *"  # 2AM daily
```

### Monitoring et Santé
#### Health Checks
```ruby
# config/routes.rb
get '/health', to: proc { 
  [
    200, 
    { 'Content-Type' => 'application/json' },
    [{ 
      status: 'OK',
      timestamp: Time.now.iso8601,
      checks: {
        database: database_healthy?,
        redis: redis_healthy?,
        sidekiq: sidekiq_healthy?
      }
    }.to_json]
  ] 
}
```
### Métriques Clés (Phase 2)
```yaml
Métriques à Surveiller:
  - orders_per_second
  - average_response_time
  - error_rate
  - database_connections
  - memory_usage
```
### Stratégie de Déploiement
#### CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
name: Deploy to VM
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: |
          ssh deploy@${{ secrets.VM_HOST }} 'cd brokerx && git pull && docker-compose up -d'
```

#### Rollback Strategy 
```bash
#!/bin/bash
# scripts/rollback.sh
ssh deploy@$VM_HOST << EOF
  cd /opt/brokerx
  docker-compose down
  git checkout previous-tag
  docker-compose up -d
EOF
```

## Sécurité Infrastructure

### Hardening
- Containers exécutés comme utilisateurs non-root

- Secrets managés via Docker Secrets ou Vault

- Logs centralisés et monitorés

- Updates de sécurité automatiques
