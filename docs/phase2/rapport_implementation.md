# Rapport d'Implémentation Phase 2 - BrokerX

**Date**: 25 novembre 2025  
**Auteur**: Équipe de développement  
**Version**: 1.0

---

## Table des matières

1. [Contexte et Motivation](#1-contexte-et-motivation)
2. [Implémentations Détaillées](#2-implémentations-détaillées)
3. [Difficultés Rencontrées et Solutions](#3-difficultés-rencontrées-et-solutions)
4. [Documentation Produite](#4-documentation-produite)
5. [Tests et Validation](#5-tests-et-validation)
6. [Métriques et Observabilité](#6-métriques-et-observabilité)
7. [Déploiement](#7-déploiement)
8. [Recommandations Futures](#8-recommandations-futures)
9. [Conclusion](#9-conclusion)

---

## Résumé Exécutif

Ce rapport documente les améliorations architecturales apportées à BrokerX dans le cadre de la Phase 2. Les travaux ont porté sur la scalabilité horizontale, la résilience des transactions, et l'observabilité de la plateforme de courtage.

### Objectifs atteints

| Objectif | Statut | Livrable |
|----------|--------|----------|
| Cache distribué Redis | Complété | Configuration + docker-compose |
| Load Balancing Nginx | Complété | `docker-compose.lb.yml` |
| Saga Pattern pour transactions | Complété | `TradingSaga` + 6 tests |
| Tests de charge k6 | Complété | 3 scripts + documentation |
| Documentation Arc42 | Complété | ADRs 008, 009, 010 |

---

## 1. Contexte et Motivation

### 1.1 Objectifs Phase 2

La Phase 2 vise à décomposer le monolithe vers des microservices pilotés par une API Gateway, avec:
- **Observabilité** prête pour démo (k6, Prometheus, Grafana)
- **Temps réel** via ActionCable (WebSockets)
- **Scalabilité** horizontale avec load balancing

**Portée Phase 2**: 
- Services Orders/Portfolios/Reporting
- Gateway Kong (DB-less)
- Métriques Prometheus + tableaux de bord Grafana
- WebSocket `/cable` pour notifications temps réel

### 1.2 Contraintes techniques

| Contrainte | Description |
|------------|-------------|
| Docker-first | Tous les services conteneurisés |
| Kong DB-less | Configuration déclarative YAML |
| Postgres unique | Base partagée pour la démo |
| JWT HS256 | Authentification stateless |
| CORS/key-auth | Sécurité au niveau gateway |

### 1.3 Cas d'usage implémentés

#### Phase 1 (réalisés précédemment)
- **UC-01** — Inscription & Vérification (email + token)
- **UC-02** — Authentification MFA (login → verify_mfa → JWT)
- **UC-05** — Placement d'ordre (pré-trade + ACK)

#### Phase 2 (réalisés)
- **UC-03** — Dépôt de fonds idempotent (Idempotency-Key)
- **UC-04** — Données de marché temps réel (ActionCable/WS)
- **UC-06** — Modifier/Annuler ordre (verrouillage optimiste)

#### Phase 3 (implémentation avancée)
- **UC-07** — Appariement d'ordres (Event-Driven + Outbox + Saga)
- **UC-08** — Confirmation d'exécution & Notifications

### 1.4 Lien avec UC-07 et UC-08

#### UC-07: Appariement d'ordres (Event-Driven + Outbox)

Le **Saga Pattern** implémenté dans `TradingSaga` orchestre le flux complet de l'appariement événementiel:

1. **Validation de l'ordre** — Vérifie fonds, limites, symbole
2. **Réservation des fonds** — Réserve le montant (achat)
3. **Création de l'ordre** — Persiste dans la DB + événement Outbox
4. **Soumission au matching** — Enqueue vers MatchingEngine

**Pattern Outbox**: Les événements `order.created` sont persistés dans la même transaction que l'ordre, garantissant l'atomicité. Le dispatcher lit périodiquement les événements `pending` et les injecte dans le moteur d'appariement.

```
UC-07 Flow avec TradingSaga + Outbox:
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
│ POST /order │───▶│ TradingSaga  │───▶│ MatchingEngine  │
└─────────────┘    │  validate    │    │ (UC-07 cœur)    │
                   │  reserve     │    └─────────────────┘
                   │  create      │           │
                   │  submit      │◀──────────┘
                   └──────────────┘
                         │
                   Si échec: compensate!
                         │
                   ┌─────▼─────┐
                   │ release   │
                   │ funds     │
                   └───────────┘
```

**Diagramme de séquence TradingSaga**:

![TradingSaga Sequence](assets/trading_saga_sequence.png)

**Événements émis**:
| Type | Source | Description |
|------|--------|-------------|
| `order.created` | Controller | Déclenche l'appariement |
| `execution.report` | MatchingEngine | Feed clients (working/filled) |
| `saga.*` | TradingSaga | Cycle de vie du saga |

#### UC-08: Confirmation d'exécution & Notifications

Le **cache Redis** et le **load balancing** garantissent des notifications fiables:

- **Sessions persistantes** entre instances pour WebSockets (ActionCable)
- **Redis Pub/Sub** pour diffusion inter-instances
- **Scalabilité** pour gérer les pics de notifications

**Flux de notification**:
1. MatchingEngine écrit `execution.report` (pending) dans Outbox
2. Dispatcher traite → broadcast temps réel (canal `orders_status:<order_id>`)
3. Email de confirmation programmé (fallback robustesse)
4. Événement marqué `processed`

```
UC-08 avec Load Balancing:
┌────────────┐     ┌─────────┐     ┌────────────┐
│ Client WS  │────▶│  Nginx  │────▶│ web-1/2/3  │
│ (notifs)   │     │   LB    │     │ ActionCable│
└────────────┘     └─────────┘     └────────────┘
                                         │
                   Redis Pub/Sub ◀───────┘
                   (sessions partagées)
```

**Diagramme du flux Outbox (UC-07/UC-08)**:

![Outbox Event Flow](assets/outbox_event_flow.png)

---

## 2. Implémentations Détaillées

### 2.1 Redis Cache Distribué

**Fichiers modifiés/vérifiés**:
- `Gemfile`: `gem 'redis', '~> 5.2'`
- `docker-compose.yml`: Service Redis 7-alpine
- `config/initializers/cache_store.rb`: Configuration du cache store

**Configuration**:
```ruby
# config/initializers/cache_store.rb
Rails.application.configure do
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    namespace: 'brokerx_cache',
    expires_in: 1.hour
  }
end
```

**Choix techniques**:
| Décision | Justification |
|----------|---------------|
| Redis 7-alpine | Image légère, dernière version stable |
| Namespace `brokerx_cache` | Isolation des clés cache vs sessions |
| TTL 1 heure par défaut | Balance fraîcheur/performance |

### 2.2 Load Balancing avec Nginx

**Fichiers créés**:
- `docker-compose.lb.yml`: Orchestration complète
- `nginx/nginx.conf`: Configuration du load balancer

**Architecture déployée**:

![Load Balancing Architecture](assets/load_balancing_architecture.png)

**Choix de l'algorithme `least_conn`**:
- Distribue vers l'instance avec le moins de connexions actives
- Meilleur que round-robin pour les requêtes de durée variable
- Idéal pour les WebSockets (connexions longues)

**Résultats des tests de distribution**:
```
Instance Distribution (test k6 avec 3793 requêtes):
- web-1 (172.x.x.4): 1213 hits (32.0%)
- web-2 (172.x.x.5): 1270 hits (33.5%)
- web-3 (172.x.x.6): 1310 hits (34.5%)

→ Distribution quasi-uniforme validée ✓
```

### 2.3 TradingSaga Pattern

**Fichier créé**: `app/application/services/trading_saga.rb`

**Étapes du Saga**:
```ruby
STEPS = %i[
  validate_order      # Vérifie fonds, limites, symbole
  reserve_funds       # Réserve fonds (buy only)
  create_order        # Persiste l'ordre en DB
  submit_to_matching  # Enqueue au MatchingEngine
]
```

**Compensations automatiques**:
| Étape échouée | Compensation |
|---------------|--------------|
| `reserve_funds` | N/A (rien à compenser) |
| `create_order` | `release_funds` |
| `submit_to_matching` | `cancel_order` + `release_funds` |

**Événements émis via Outbox**:
```ruby
# Événements de cycle de vie du saga
saga.started           # Début du saga
saga.step.completed    # Étape réussie
saga.step.failed       # Étape échouée
saga.compensating      # Compensation en cours
saga.completed         # Saga terminé avec succès
saga.failed            # Saga échoué (après compensation)
```

**Intégration avec UC-07**:
Le dispatcher Outbox (`outbox_dispatcher.rb`) a été modifié pour gérer les nouveaux événements saga.* et les propager aux métriques Prometheus.

### 2.4 Tests de Charge k6

**Scripts créés** dans `load/k6/`:

| Script | Objectif | Configuration |
|--------|----------|---------------|
| `load.js` | Charge soutenue | 50 VUs pendant 5 min |
| `stress.js` | Test de stress | 0→100→300→500→0 VUs |
| `lb_test.js` | Vérification LB | 20 VUs, analyse distribution |

**Commandes d'exécution**:
```bash
# Test de charge soutenue
k6 run load/k6/load.js

# Test de stress progressif
k6 run load/k6/stress.js

# Vérification load balancing (nécessite docker-compose.lb.yml)
docker compose -f docker-compose.lb.yml up -d
k6 run load/k6/lb_test.js
```

---

## 3. Difficultés Rencontrées et Solutions

### 3.1 Tests TradingSaga - Attributs ClientRecord

**Problème**: Les tests échouaient avec l'erreur:
```
NoMethodError: undefined method 'name=' for ClientRecord
```

**Cause**: Le modèle `ClientRecord` utilise `first_name` et `last_name` séparément, pas un attribut `name`.

**Solution**: Modification des fixtures de test pour utiliser les bons attributs:
```ruby
# Avant (incorrect)
ClientRecord.create!(name: 'Test User', email: 'test@test.com')

# Après (correct)
ClientRecord.create!(
  first_name: 'Test',
  last_name: 'User',
  email: 'test@test.com',
  password_digest: BCrypt::Password.create('password')
)
```

### 3.2 Identification des instances dans les tests LB

**Problème**: Le header `X-Instance` retournait "web" au lieu de l'identifiant d'instance spécifique.

**Cause**: Le middleware `InstanceHeaderMiddleware` utilisait `Socket.gethostname` qui retourne le nom du service Docker, pas le numéro d'instance.

**Solution**: Utilisation du header `X-Upstream-Server` ajouté par Nginx qui contient l'IP de l'instance upstream. Mapping des IPs aux instances:
```
172.x.x.4 → web-1
172.x.x.5 → web-2
172.x.x.6 → web-3
```

### 3.3 Erreurs HTTP dans les tests k6

**Problème**: Les tests k6 montraient un taux d'échec HTTP élevé.

**Cause**: Les requêtes non authentifiées retournent 401, ce que k6 compte comme "failed".

**Solution**: C'est un comportement attendu. Les tests valident la disponibilité du service, pas l'authentification. Les 401 confirment que l'API répond correctement.

### 3.4 Configuration Nginx pour WebSockets

**Problème**: Les connexions WebSocket (ActionCable) ne fonctionnaient pas à travers le load balancer.

**Solution**: Ajout des headers de proxy WebSocket dans `nginx.conf`:
```nginx
location /cable {
    proxy_pass http://brokerx_app;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;  # 24h pour connexions longues
}
```

---

## 4. Documentation Produite

### 4.1 ADRs (Architecture Decision Records)

| ADR | Titre | Fichier |
|-----|-------|---------|
| 008 | Redis Cache Distribué | `docs/architecture/adr008_redis_cache.md` |
| 009 | Load Balancing Nginx | `docs/architecture/adr009_load_balancing.md` |
| 010 | Saga Pattern | `docs/architecture/adr010_saga_pattern.md` |

### 4.2 Mise à jour Arc42

Sections mises à jour dans `docs/architecture/arc42/arc42.md`:
- **Section 9**: Tableau des 10 ADRs avec liens
- **Section 10**: Tests de charge k6 (scripts, commandes, résultats)
- **Section 11**: Tableau des améliorations Phase 2 implémentées

### 4.3 Documentation k6

Fichier `load/k6/README.md` créé avec:
- Prérequis et installation
- Description de chaque script
- Commandes d'exécution
- Interprétation des résultats
- Métriques clés à surveiller

---

## 5. Tests et Validation

### 5.1 Tests Unitaires TradingSaga

**6 tests implémentés** dans `test/unit/trading_saga_test.rb`:

```
1. ✓ successful saga execution for buy order
2. ✓ successful saga execution for sell order
3. ✓ saga fails on validation error
4. ✓ saga compensates on order creation failure
5. ✓ saga compensates on matching submission failure
6. ✓ saga emits correct events
```

**Exécution**:
```bash
rails test test/unit/trading_saga_test.rb
# 6 runs, 6 assertions, 0 failures, 0 errors
```

### 5.2 Tests de Load Balancing

**Validation de la distribution**:
```bash
docker compose -f docker-compose.lb.yml up -d
k6 run load/k6/lb_test.js
```

**Critères de succès**:
- [x] Distribution entre 25% et 40% par instance
- [x] Toutes les instances reçoivent des requêtes
- [x] Temps de réponse P95 < 500ms

### 5.3 Tests de Santé des Services

```bash
# Vérification des services
curl http://localhost/health        # → 200 OK
curl http://localhost/api/v1/health # → 200 OK
```

---

## 6. Métriques et Observabilité

### 6.1 Architecture Observabilité

![Observability Stack](assets/observability_stack.png)

### 6.2 Nouvelles Métriques Prometheus

```ruby
# Métriques TradingSaga
saga_started_total
saga_completed_total{status="success|failed"}
saga_compensations_total
saga_steps_total{step="...", status="completed|failed"}

# Métriques existantes enrichies
outbox_events_total{type="saga.*", status}
```

### 6.3 Captures Prometheus

**Targets Prometheus** (toutes les cibles UP):

![Prometheus Targets](assets/prometheus_targets.png)

**Expression Latence P95**:

![Prometheus Latency P95](assets/prometheus_expressions_latency.png)

### 6.4 Dashboards Grafana

**Vue d'ensemble Golden Signals**:

![Grafana Overview](assets/grafana_overview.png)

**Panneaux Gateway/Kong**:

![Grafana Gateway Panels](assets/grafana_gateway_panels.png)

### 6.5 Dashboards Recommandés

| Dashboard | Métriques clés |
|-----------|----------------|
| Trading Saga | Taux succès/échec, compensations, durée |
| Load Balancer | Distribution par instance, latence |
| Outbox | Événements pending/processed/failed |

---

## 7. Déploiement

### 7.1 Commandes de déploiement

```bash
# Environnement standard (dev)
docker compose up -d

# Environnement load balancé (prod-like)
docker compose -f docker-compose.lb.yml up -d

# Vérification
docker compose -f docker-compose.lb.yml ps
```

### 7.2 Configuration requise

| Variable | Description | Défaut |
|----------|-------------|--------|
| `REDIS_URL` | URL Redis | `redis://redis:6379/1` |
| `INSTANCE_ID` | ID de l'instance | hostname |
| `DATABASE_URL` | URL PostgreSQL | configuré dans compose |

---

## 8. Recommandations Futures

### 8.1 Améliorations à court terme
- [ ] Ajouter retry automatique pour les sagas échouées
- [ ] Implémenter les fills partiels (UC-07)
- [ ] Dashboard Grafana dédié aux sagas

### 8.2 Améliorations à moyen terme
- [ ] Migration vers message broker externe (Kafka/RabbitMQ)
- [ ] Auto-scaling basé sur les métriques
- [ ] Circuit breaker pour le MatchingEngine

### 8.3 Améliorations à long terme
- [ ] Découpage en microservices (TradingService, NotificationService)
- [ ] Event sourcing complet
- [ ] CQRS pour les lectures

---

## 9. Conclusion

Les implémentations Phase 2 apportent des améliorations significatives à BrokerX:

1. **Scalabilité**: 3 instances web derrière Nginx avec distribution équilibrée
2. **Résilience**: Saga Pattern garantit la cohérence des transactions
3. **Performance**: Cache Redis partagé entre instances
4. **Observabilité**: Tests k6 formalisés et documentés
5. **Traçabilité**: ADRs documentant chaque décision

Ces fondations permettent d'envisager sereinement l'évolution vers une architecture microservices tout en maintenant la cohérence métier requise pour une plateforme de courtage.

---

## Annexes

### A. Arborescence des fichiers créés/modifiés

```
brokerx/
├── docker-compose.lb.yml          # CRÉÉ - Orchestration LB
├── nginx/
│   └── nginx.conf                  # CRÉÉ - Config Nginx
├── app/
│   ├── application/services/
│   │   ├── trading_saga.rb         # CRÉÉ - Saga orchestrator
│   │   └── outbox_dispatcher.rb    # MODIFIÉ - Support saga.*
│   └── middleware/
│       └── instance_header_middleware.rb  # MODIFIÉ - INSTANCE_ID
├── test/unit/
│   └── trading_saga_test.rb        # CRÉÉ - 6 tests
├── load/k6/
│   ├── load.js                     # CRÉÉ - Test charge
│   ├── stress.js                   # CRÉÉ - Test stress
│   ├── lb_test.js                  # CRÉÉ - Test LB
│   └── README.md                   # CRÉÉ - Documentation
└── docs/
    └── architecture/
        ├── adr008_redis_cache.md   # CRÉÉ
        ├── adr009_load_balancing.md # CRÉÉ
        ├── adr010_saga_pattern.md  # CRÉÉ
        └── arc42/arc42.md          # MODIFIÉ - Sections 9, 10, 11
```

### B. Diagrammes PlantUML

Les diagrammes suivants ont été créés dans `docs/phase2/assets/`:

| Fichier | Description |
|---------|-------------|
| `trading_saga_sequence.puml` | Séquence complète du TradingSaga avec compensation |
| `load_balancing_architecture.puml` | Architecture Nginx + 3 instances web |
| `outbox_event_flow.puml` | Flux Outbox Pattern (UC-07/UC-08) |
| `observability_stack.puml` | Stack Prometheus + Grafana |

**Régénérer les images PNG**:
```bash
cd docs/phase2/puml
for f in *.puml; do 
  docker run --rm -v "$(pwd)":/data plantuml/plantuml -tpng "/data/$f"
done
```

### C. Références

- [Arc42 Template](https://arc42.org/)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html)
- [k6 Documentation](https://k6.io/docs/)
- [Nginx Load Balancing](https://nginx.org/en/docs/http/load_balancing.html)
- [PlantUML](https://plantuml.com/)
