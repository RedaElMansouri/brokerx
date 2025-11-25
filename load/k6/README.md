# Load Testing avec k6

Ce dossier contient les scripts de test de charge pour BrokerX utilisant [k6](https://k6.io/).

## 📋 Prérequis

### Installation de k6

```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Docker
docker pull grafana/k6
```

## 🎯 Scripts disponibles

| Script | Type | Description | Durée |
|--------|------|-------------|-------|
| `smoke.js` | Smoke | Vérification rapide que tout fonctionne | 1 min |
| `load.js` | Load | Charge normale soutenue | 9 min |
| `spike.js` | Spike | Pic soudain de trafic | ~1 min |
| `stress.js` | Stress | Trouver le point de rupture | 17 min |
| `lb_test.js` | LB | Valider la distribution nginx | 1 min |
| `gateway_smoke.js` | Smoke | Test via Kong API Gateway | 45s |
| `gateway_benchmark.js` | Benchmark | Benchmark complet via Gateway | 5 min |

## 🚀 Exécution

### Configuration de base

```bash
# Variables d'environnement disponibles
export BASE_URL=http://localhost:3000   # URL de l'application
export TOKEN=your-jwt-token              # Token d'authentification
export SYMBOL=AAPL                       # Symbole boursier à utiliser
export VUS=10                            # Nombre d'utilisateurs virtuels
export DURATION=2m                       # Durée du test
```

### Obtenir un token

```bash
# 1. Créer un client (si nécessaire)
curl -X POST http://localhost:3000/api/v1/clients \
  -H "Content-Type: application/json" \
  -d '{"client":{"first_name":"Load","last_name":"Test","email":"loadtest@example.com","password":"password123","date_of_birth":"1990-01-01"}}'

# 2. Se connecter pour obtenir le token
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"loadtest@example.com","password":"password123"}'

# Réponse: {"token":"eyJhbGciOiJIUzI1..."}
export TOKEN="eyJhbGciOiJIUzI1..."
```

### Exécuter les tests

```bash
# Smoke test (vérification rapide)
k6 run load/k6/smoke.js

# Load test (charge normale)
k6 run load/k6/load.js --env TOKEN=$TOKEN

# Stress test (trouver les limites)
k6 run load/k6/stress.js --env TOKEN=$TOKEN

# Spike test (pic soudain)
k6 run load/k6/spike.js --env TOKEN=$TOKEN

# Test du load balancer (nécessite docker-compose.lb.yml)
docker compose -f docker-compose.lb.yml up -d
k6 run load/k6/lb_test.js --env BASE_URL=http://localhost

# Test via Gateway (nécessite docker-compose.gateway.yml)
docker compose -f docker-compose.gateway.yml up -d
k6 run load/k6/gateway_smoke.js --env BASE_URL=http://localhost:8080 --env TOKEN=$TOKEN
```

## 📊 Métriques et Thresholds

### Métriques standard k6

| Métrique | Description |
|----------|-------------|
| `http_req_duration` | Temps de réponse HTTP |
| `http_req_failed` | Taux d'échec HTTP |
| `http_reqs` | Nombre total de requêtes |
| `vus` | Utilisateurs virtuels actifs |

### Métriques custom BrokerX

| Métrique | Description |
|----------|-------------|
| `order_create_latency_ms` | Latence création d'ordre |
| `portfolio_get_latency_ms` | Latence lecture portfolio |
| `orders_created_total` | Ordres créés avec succès |
| `instance_web*_hits` | Distribution par instance (LB) |

### Thresholds recommandés

| Scénario | p95 Latency | Error Rate |
|----------|-------------|------------|
| Smoke | < 500ms | < 1% |
| Load | < 500ms | < 1% |
| Stress | < 2000ms | < 10% |
| Spike | < 600ms | < 5% |

## 🔄 Intégration CI/CD

### GitHub Actions

```yaml
# .github/workflows/load-test.yml
name: Load Tests

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  load-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: brokerx_test
          POSTGRES_USER: brokerx
          POSTGRES_PASSWORD: password
        ports:
          - 5432:5432
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4
      
      - name: Setup k6
        run: |
          curl -L https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz | tar xz
          sudo mv k6-v0.47.0-linux-amd64/k6 /usr/local/bin/
      
      - name: Start application
        run: |
          docker compose up -d
          sleep 30  # Wait for app to be ready
      
      - name: Run smoke test
        run: k6 run load/k6/smoke.js --env BASE_URL=http://localhost:3000
      
      - name: Run load test
        run: k6 run load/k6/load.js --env BASE_URL=http://localhost:3000 --env DURATION=2m
```

## 📈 Export des résultats

### Format JSON

```bash
k6 run load/k6/load.js --out json=results.json
```

### Vers InfluxDB + Grafana

```bash
# Lancer InfluxDB
docker run -d -p 8086:8086 influxdb:1.8

# Exécuter avec export
k6 run load/k6/load.js --out influxdb=http://localhost:8086/k6
```

### Vers Prometheus

```bash
# Avec l'extension xk6-prometheus
k6 run load/k6/load.js --out experimental-prometheus-rw
```

## 🐛 Troubleshooting

### Erreur "connection refused"

```bash
# Vérifier que l'application tourne
curl http://localhost:3000/health

# Vérifier les logs
docker compose logs web
```

### Beaucoup d'erreurs 401

```bash
# Le token a peut-être expiré, en générer un nouveau
export TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"loadtest@example.com","password":"password123"}' | jq -r '.token')
```

### Erreurs 422 sur les ordres

```bash
# Probablement pas assez de fonds, faire un dépôt
curl -X POST http://localhost:3000/api/v1/deposits \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 100000, "currency": "USD"}'
```

## 📚 Ressources

- [Documentation k6](https://k6.io/docs/)
- [k6 Best Practices](https://k6.io/docs/testing-guides/api-load-testing/)
- [Grafana k6 Cloud](https://k6.io/cloud/)
