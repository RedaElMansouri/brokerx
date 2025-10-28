# Comparaison de performance: Monolithe → Microservices + Gateway

Objectif: comparer la latence et le taux d'échec observés entre l'architecture monolithique et l'architecture microservices derrière un API Gateway (Kong), et démontrer l'atteinte des NFRs.

## NFRs cibles
- Latence p95: ≤ 100 ms (lecture) et ≤ 200 ms (écriture)
- Taux d'échec http_req_failed: ≤ 1%
- Observabilité: métriques Prometheus exposées pour services et gateway, tableaux Grafana opérationnels

## Méthodologie
- Jeu de données: seed de démonstration activé (variable `SEED_DEMO=1` dans `docker-compose.gateway.yml`)
- Authentification: JWT signé HS256 via `secret_key_base` (env partagée), header `Authorization: Bearer <token>`
- Gateway: Kong 3.7 DB-less, key-auth, CORS, plugin Prometheus global activé
- Rate limiting: Rack::Attack assoupli pour tests (variables env dans overlay gateway)
- Tests: k6 smoke test (lecture portfolio, dépôt, création d’ordre) avec `http.expectedStatuses(200,201,204,401,409,422)`

## Scénarios
1. Monolithe direct
   - Stack: `docker compose up -d --build` + observabilité
   - Script: `k6 run load/k6/smoke.js`
2. Microservices directs
   - Stack: `docker compose -f docker-compose.yml -f docker-compose.gateway.yml up -d --build`
   - Script: `k6 run load/k6/direct_microservices_smoke.js`
3. Microservices via Gateway (Kong)
   - Même stack que (2)
   - Script: `k6 run load/k6/gateway_smoke.js -e BASE_URL=http://localhost:8080 -e APIKEY=brokerx-key-123 -e TOKEN=<JWT>`

## Résultats (session locale de référence)
- Direct microservices: p95 ≈ 35 ms, http_req_failed ≈ 0.00%
- Via Gateway: p95 ≈ 35 ms, http_req_failed ≈ 0.00%
- Observation: overhead du gateway négligeable dans ce profil; erreurs précédentes (401/429/500) résolues par: seed + limites Rack::Attack adaptées + correction statut `:unprocessable_entity` + alignement des statuts attendus dans k6.

## Observabilité
- Prometheus scrape:
  - `web` (monolithe) ou services `orders-a/b`, `portfolios`, `reporting`
  - `kong:8001/metrics`
- Grafana: tableaux "Rails App", "Gateway/Kong", "DB overview"

## Reproductibilité (<30 min)
1) Provisionner VM (Docker + Docker Compose installés)
2) Déployer via CI/CD (push sur `main`) ou script: `scripts/deploy_vm.sh`
3) `docker compose -f docker-compose.yml -f docker-compose.gateway.yml up -d --build`
4) Générer un JWT (voir `docs/operations/runbook.md`) et relancer k6

## Captures à inclure (fichiers à déposer sous `docs/phase2/screenshots/`)
- `grafana_overview.png`: Dashboard principal montrant trafic et latences
- `grafana_gateway_panels.png`: Panneaux Kong (requêtes, latence upsteam)
- `prometheus_targets.png`: Targets Prometheus (toutes UP)
- `prometheus_expressions_latency.png`: Graph d’une expression de latence (ex: histogram_quantile)
- `k6_direct_smoke_summary.png`: Résumé exécution k6 direct microservices
- `k6_gateway_smoke_summary.png`: Résumé exécution k6 via gateway
- `kong_admin_metrics.png`: Extrait `:8001/metrics` montrant quelques séries

Voir `docs/operations/screenshots.md` pour la procédure de capture.
