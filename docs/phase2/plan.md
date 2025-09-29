# Phase 2 — Plan de transition (BrokerX+)

## Contexte et objectifs
Vous poursuivez le rôle d’architecte logiciel pour BrokerX+, plateforme de courtage en ligne. Après la phase 1 (monolithe évolutif), la phase 2 vise :
- Exposer une API RESTful sécurisée (CORS, auth Basic/JWT), documentée (OpenAPI/Swagger)
- Industrialiser l’observabilité et la performance (logs structurés, métriques Prometheus, dashboards Grafana, tests de charge)
- Évoluer vers des microservices publiés via une API Gateway (routage, sécurité, A/B direct vs gateway)
- Respecter les NFR (latence P95, throughput, disponibilité), conformité et audit

Livrer avec traçabilité (Arc42, 4+1, ADR) et des gains mesurés sur les 4 Golden Signals.

## Livrables et critères d’acceptation (CA)
1) API REST & sécurité
- Endpoints versionnés /api/v1, codes HTTP et erreurs JSON normalisées (RFC 7807-like)
- OpenAPI (Swagger UI) et collection Postman publiées
- CORS configuré, auth Basic/JWT
- CA : routes cohérentes, Swagger accessible, smoke tests OK

2) Persistance & intégrité
- Migrations reproductibles, contraintes (unicité, FK, index), seeds
- Repositories/ORM, transactions, idempotency-key sur endpoints sensibles (dépôts/ordres)
- Journal d’audit append-only
- CA : CRUD robustes, rollback sur erreurs, tests d’intégration DB conteneurisée

3) Observabilité & performance
- Logs structurés (JSON), corrélation (request_id, user_id)
- Métriques Prometheus: HTTP RPS, latences P50/P95/P99, 4xx/5xx, DB calls, saturation (CPU/RAM/threads)
- Dashboards Grafana 4 Golden Signals
- Tests de charge (k6 ou JMeter) avec scénarios réalistes et seuils
- CA : dashboards + tableaux comparatifs avant/après

4) Load balancing & caching
- LB (NGINX/Traefik/HAProxy) sur 1→N instances, tolérance aux pannes
- Caching mémoire/Redis pour endpoints coûteux (carnets, cotations, rapports)
- Mesure des gains/risques (stale)
- CA : graphiques X=instances, Y=latence/RPS/erreurs/saturation

5) Microservices & API Gateway
- Découpage logique : ≥3–4 services (Comptes/Clients, Ordres/Matching, Portefeuilles, Marché/Reporting)
- Gateway (Kong/KrakenD/Spring Cloud Gateway): routage, CORS, clé API, headers, (optionnels : quota, rate limiting)
- Comparaison sous charge: direct vs gateway
- CA : appels fonctionnels via Gateway, gains/impacts mesurés

6) CI/CD & conteneurisation
- Dockerfiles multi-stage, docker-compose (app + DB + Prometheus + Grafana + Gateway + seed), healthchecks
- CI : lint → build → tests → artefacts, badge; CD simple (compose/systemd)
- CA : pipeline < 10 min, déploiement 1 commande

7) Documentation & ADR
- Arc42 §§1–8 et 4+1 à jour; ≥3 ADRs (style archi, persistance/transactions, versionnage/erreurs, conformité/audit)
- Rapport comparatif REST → optimisé (LB/cache) → microservices+Gateway
- CA : reproductibilité < 30 min (VM), liens/captures Grafana/Prometheus

## Plan d’exécution (étapes)

### Semaine 1 — API REST et sécurité
- Normaliser routes/erreurs (concerns/API::Errors), ajouter `/api/v1/docs` (swagger-ui)
- Mettre en place auth Basic/JWT propre (bcrypt, rotations, TTL), CORS
- Ajouter tests e2e Postman/newman basiques

### Semaine 2 — Observabilité et charge
- Logs JSON (Rails.logger → JSON), propag. request_id, structured logging dans controllers/services
- Exporter métriques (prometheus_exporter ou yjit prometheus client), endpoints `/metrics`
- Déployer Prometheus+Grafana via compose; créer dashboards (HTTP, DB, VM)
- Écrire scénarios k6/JMeter (auth, get market data, place orders cadence)

### Semaine 3 — LB et caching
- Dockerize app; NGINX/Traefik en frontal, règles de LB (round-robin, sticky optional) ; 1→2→3→4 instances
- Redis ou cache mémoire pour endpoints coûteux; expiration/invalidation par clé
- Repasser les campagnes de charge, collecter métriques et grapher

### Semaine 4 — Microservices et Gateway
- Extraire services (ex : Orders & Matching, Portfolios, Market Data)
- Publier via Kong/KrakenD; config routes, clés API, CORS; LB côté Gateway
- Campagne A/B Direct vs Gateway sous charge; reporter métriques

### Semaine 5 — CI/CD et docs
- CI GitHub Actions (lint/build/test, artefacts, badge), CD compose (scripts deploy/rollback)
- Finaliser Arc42+4+1, rédiger ≥3 ADRs, runbook (opérations, obs, pannes)
- Synthèse PDF, captures dashboards, tableaux comparatifs

## Outillage recommandé
- API : rswag (Rails Swagger), rack-cors, devise-jwt/jwt, bcrypt
- Obs : prometheus_exporter, grafana, loki (optionnel), lograge ou custom JSON logger
- Charge : k6 (scripts JS) ou JMeter
- LB : NGINX ou Traefik, docker-compose scale
- Cache : redis, redis-rails ou rack-cache
- Gateway : Kong ou KrakenD
- CI : GitHub Actions; Conteneurs : Docker, Compose

## Mesures et seuils (exemple)
- Latence P95 Auth: < 200 ms; Get Market Data: < 120 ms; Place Order: < 300 ms
- RPS cible: 200–500 en monolith avec LB 2–4 instances
- Erreurs: < 1% 5xx ; 4xx monitorées
- Saturation: CPU < 75% P95, RAM stable, threads workers non saturés

## Traçabilité
- 4+1 (scénarios, logique, processus, déploiement, dev) sous `docs/architecture/4plus1_views`
- Arc42 sous `docs/architecture/arc42`
- ADRs sous `docs/architecture/adr`
