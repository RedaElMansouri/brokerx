---
marp: true
theme: default
paginate: true
backgroundColor: #ffffff
color: #1d1d1d
style: |
  section {
    font-family: 'Segoe UI', 'Calibri', Arial, sans-serif;
    background-color: #ffffff;
  }
  h1 {
    color: #217346;
    border-bottom: 3px solid #217346;
    padding-bottom: 10px;
  }
  h2 {
    color: #217346;
  }
  code {
    background: #f3f3f3;
    color: #1d1d1d;
    border: 1px solid #d4d4d4;
  }
  table {
    font-size: 0.75em;
    border-collapse: collapse;
  }
  th {
    background-color: #217346;
    color: white;
  }
  td, th {
    border: 1px solid #d4d4d4;
    padding: 8px;
  }
  tr:nth-child(even) {
    background-color: #f3f3f3;
  }
  strong {
    color: #217346;
  }
---

<!-- _class: lead -->

# BrokerX
## Plateforme de Courtage en Ligne

**Phases 1, 2 & 3 — Architecture Logicielle**

---

Présenté par: **Reda El Mansouri**
Cours: **LOG430** - Architecture Logicielle
Date: **25 novembre 2025**

---

# Vue d'ensemble du Projet

## BrokerX: Plateforme de courtage complète

**8 Use Cases** implémentés en **3 phases**:

| Phase | Focus | Use Cases |
|-------|-------|-----------|
| **Phase 1** | Fondations DDD | UC-01, UC-02, UC-05 |
| **Phase 2** | Microservices & Temps réel | UC-03, UC-04, UC-06 |
| **Phase 3** | Saga & Scalabilité | UC-07, UC-08 |

---

# Architecture Globale

```
┌──────────────────────────────────────────────────────┐
│              Kong API Gateway                         │
│         (Auth JWT, Rate Limiting, Routing)           │
└─────────────────────┬────────────────────────────────┘
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
     ┌────────┐  ┌────────┐  ┌────────┐
     │ Web 1  │  │ Web 2  │  │ Web 3  │   ← Nginx LB
     └───┬────┘  └───┬────┘  └───┬────┘     (least_conn)
         └───────────┼───────────┘
                     ▼
         ┌───────────────────────┐
         │  PostgreSQL + Redis   │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
    Prometheus              ActionCable
    + Grafana               (WebSocket)
```

---

# Déploiement — Docker Compose

## Architecture conteneurisée

| Fichier | Services |
|---------|----------|
| `docker-compose.yml` | web, postgres, redis |
| `docker-compose.gateway.yml` | kong |
| `docker-compose.lb.yml` | nginx, web1, web2, web3 |
| `docker-compose.observability.yml` | prometheus, grafana |

**Commande de démarrage:**
```bash
docker compose -f docker-compose.yml \
  -f docker-compose.gateway.yml \
  -f docker-compose.lb.yml \
  -f docker-compose.observability.yml up -d
```

**Seed:** Données de test pré-chargées (clients, portfolios, symboles)

---

<!-- _class: lead -->

# Phase 1
## Fondations & DDD

---

# Phase 1 — Objectifs

## Domain-Driven Design & Authentification

**Use Cases implémentés:**
- **UC-01**: Inscription & Vérification email
- **UC-02**: Authentification MFA (2 étapes)
- **UC-05**: Placement d'ordre (prototype)

**Patterns appliqués:**
- Architecture DDD (Domain, Application, Infrastructure)
- Repository Pattern
- Value Objects (Email, Money)

---

# Phase 1 — Architecture DDD

```
app/
├── domain/           # Entités, Value Objects, Interfaces
│   ├── clients/
│   │   ├── entities/     → Client, Portfolio
│   │   ├── value_objects/ → Email, Money
│   │   └── repositories/  → Interfaces
│   └── shared/
│
├── application/      # Use Cases, Services
│   └── use_cases/    → AuthenticateUser, RegisterClient
│
└── infrastructure/   # Implémentations concrètes
    ├── persistence/  → ActiveRecord Repositories
    └── web/          → Controllers
```

**Pourquoi DDD?** Séparation claire métier/technique

---

# Phase 1 — Authentification MFA

```
┌────────┐     POST /login      ┌─────────────┐
│ Client │ ─────────────────────▶│   Server    │
└────────┘     email + password  └──────┬──────┘
                                        │
     ◀─────────── MFA Code ─────────────┘
                 (email/SMS)
                                        
┌────────┐   POST /verify_mfa   ┌─────────────┐
│ Client │ ─────────────────────▶│   Server    │
└────────┘     mfa_code          └──────┬──────┘
                                        │
     ◀─────────── JWT Token ────────────┘
```

**Sécurité:** Code MFA expire en 10 minutes

---

<!-- _class: lead -->

# Phase 2
## Microservices & Temps Réel

---

# Phase 2 — Objectifs

## Gateway, WebSocket & Observabilité

**Use Cases implémentés:**
- **UC-03**: Dépôt de fonds (idempotent)
- **UC-04**: Données marché temps réel
- **UC-06**: Modifier/Annuler ordre

**Patterns appliqués:**
- API Gateway (Kong DB-less)
- WebSocket (ActionCable)
- Idempotency Pattern

---

# Phase 2 — Kong API Gateway

## Pourquoi une API Gateway?

| Sans Gateway | Avec Kong |
|--------------|-----------|
| Auth dispersée | Auth centralisée |
| Pas de rate limit | Rate limiting intégré |
| CORS par service | CORS unifié |
| Monitoring difficile | Métriques centralisées |

**Configuration:** DB-less (YAML déclaratif)

---

# Phase 2 — Temps Réel (ActionCable)

```javascript
// Client WebSocket
const cable = ActionCable.createConsumer('/cable');

cable.subscriptions.create("MarketChannel", {
  received(data) {
    // Prix mis à jour en temps réel
    updatePrice(data.symbol, data.price);
  }
});
```

**UC-04:** Prix de marché pushés toutes les secondes
**Avantage:** Pas de polling, latence minimale

---

# Phase 2 — Idempotence (UC-03)

## Dépôt de fonds sans doublons

```http
POST /api/v1/portfolios/1/deposit
Content-Type: application/json
Idempotency-Key: dep-12345-abc

{ "amount": 1000.00, "currency": "USD" }
```

**Problème:** Client retry → dépôt dupliqué?
**Solution:** `Idempotency-Key` stocké en Redis

| 1er appel | Retry | Résultat |
|-----------|-------|----------|
| Traité | Ignoré | Même réponse |

---

<!-- _class: lead -->

# Phase 3
## Saga Pattern & Scalabilité

---

# Phase 3 — Objectifs

## Transactions distribuées & Load Balancing

**Use Cases implémentés:**
- **UC-07**: Appariement d'ordres (Event-Driven)
- **UC-08**: Confirmations & Notifications

**Patterns appliqués:**
- **Saga Pattern** (orchestration)
- **Outbox Pattern** (cohérence événementielle)
- **Load Balancing** (Nginx least_conn)

---

# Phase 3 — Saga Pattern

## Pourquoi le Saga Pattern?

| Problème | Solution Saga |
|----------|---------------|
| Transaction multi-entités | Orchestration par étapes |
| Échec à mi-chemin | Compensation automatique |
| Couplage fort | Services découplés |

**Alternative rejetée:** 2PC (Two-Phase Commit)
→ Bloquant, ne scale pas

---

# Phase 3 — TradingSaga Flow

![height:420px](../puml/trading_saga_sequence.png)

---

# Phase 3 — TradingSaga Code

```ruby
class TradingSaga
  STEPS = [
    :validate_order,    # 1. Vérifier symbole, quantité
    :reserve_funds,     # 2. Réserver montant
    :create_order,      # 3. Persister en DB
    :submit_to_matching # 4. Envoyer au matching
  ]
  
  def execute(params)
    STEPS.each { |step| execute_step(step, params) }
  rescue StepError => e
    compensate!  # Rollback inverse
  end
end
```

**Compensation:** Étape 4 échoue → Annuler ordre → Libérer fonds

---

# Phase 3 — Load Balancing

![height:380px](../puml/load_balancing_architecture.png)

**Algorithme:** `least_conn` (vers serveur le moins chargé)

---

# Observabilité — Stack Complète

![height:400px](../puml/observability_stack.png)

---

# Observabilité — Golden Signals

## 4 métriques essentielles (Google SRE)

| Signal | Métrique | Seuil |
|--------|----------|-------|
| **Latency** | p95 response time | < 100ms |
| **Traffic** | Requests/sec | baseline |
| **Errors** | HTTP 5xx rate | < 1% |
| **Saturation** | CPU/Memory | < 80% |

---

# Dashboard Grafana — Golden Signals

![height:450px](../screenshots/grafana_golden_signals.png)

---

# Dashboard Grafana — Kong Gateway (1/2)

![height:450px](../screenshots/grafana_kong_gateway_1.png)

---

# Dashboard Grafana — Kong Gateway (2/2)

![height:450px](../screenshots/grafana_kong_gateway_2.png)

---

# DÉMONSTRATION

## Scénario complet:

1. **Phase 1:** Login MFA → JWT Token
2. **Phase 2:** Dépôt idempotent + WebSocket
3. **Phase 3:** Ordre d'achat (Saga) + Métriques

---

# Résultats Tests de Charge (k6)

| Métrique | Phase 2 | Phase 3 |
|----------|---------|---------|
| Requêtes | 845 | 1,200+ |
| **Latence p95** | 36ms | **35ms** |
| Latence p99 | 40ms | 89ms |
| Taux d'erreur | **0%** | **0%** |
| Throughput | 18 req/s | ~50 req/s |

Performance maintenue malgré la complexité ajoutée

---

# Documentation Produite

## ADRs (Architecture Decision Records)

| ADR | Décision |
|-----|----------|
| 001 | Style architectural DDD |
| 002 | Stratégie de persistance |
| 005 | Kong API Gateway DB-less |
| 006 | Prometheus + Grafana |
| 007 | ActionCable WebSocket |
| 008 | Redis Cache distribué |
| 009 | Nginx Load Balancing |
| 010 | Saga Pattern |

---

# Conclusion

## Évolution architecturale en 3 phases

| Phase | Apport |
|-------|--------|
| **1** | Fondations DDD solides |
| **2** | Découplage via Gateway + Temps réel |
| **3** | Résilience (Saga) + Scalabilité (LB) |

**Patterns clés:** DDD, Repository, API Gateway, Saga, Outbox, CQRS

---

<!-- _class: lead -->

# Merci!

## Questions?

🔗 GitHub: `github.com/RedaElMansouri/brokerx`
