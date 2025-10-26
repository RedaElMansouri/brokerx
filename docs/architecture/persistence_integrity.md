# Persistance & Intégrité (Phase 2 — Étape 3)

Ce document décrit le modèle de données, les contraintes d’intégrité, les stratégies de transactions, l’implémentation via Repository/ORM, l’idempotence, le journal d’audit append-only, et les critères d’acceptation liés à la persistance.

## 1) Schéma & intégrité

### 1.1 Modèle ER (Mermaid)
```mermaid
erDiagram
  CLIENTS ||--o{ PORTFOLIOS : has
  CLIENTS ||--o{ ORDERS : places
  CLIENTS ||--o{ PORTFOLIO_TRANSACTIONS : owns
  ORDERS ||--o{ TRADES : results_in

  CLIENTS {
    bigint id PK
    string email UNIQUE
    string first_name
    string last_name
    date   date_of_birth
    string status
  }

  PORTFOLIOS {
    bigint id PK
    bigint account_id UNIQUE -> CLIENTS.id
    string currency
    decimal available_balance
    decimal reserved_balance
  }

  ORDERS {
    bigint id PK
    bigint account_id -> CLIENTS.id
    string symbol
    string order_type
    string direction
    int    quantity
    decimal price
    string time_in_force
    string status
    decimal reserved_amount
    int    lock_version
  }

  PORTFOLIO_TRANSACTIONS {
    bigint id PK
    bigint account_id -> CLIENTS.id
    string operation_type
    decimal amount
    string currency
    string status
    string idempotency_key (partial UNIQUE with account_id)
    json   metadata
    timestamptz settled_at
  }

  TRADES {
    bigint id PK
    bigint order_id -> ORDERS.id
    bigint account_id -> CLIENTS.id
    string symbol
    int    quantity
    decimal price
    string side
    string status
  }
```

### 1.2 Contraintes (état actuel)
- Unicité:
  - clients.email (unique)
  - portfolios.account_id (unique)
  - portfolio_transactions (account_id, idempotency_key) unique partiel (si idempotency_key non nul)
- Index:
  - clients: status, verification_token, password_digest, mfa_code
  - orders: account_id, symbol, status
  - portfolios: account_id, currency
  - portfolio_transactions: account_id, status
  - trades: order_id, account_id, symbol
- Clés étrangères (à introduire):
  - orders.account_id → clients.id
  - portfolios.account_id → clients.id
  - portfolio_transactions.account_id → clients.id
  - trades.order_id → orders.id ; trades.account_id → clients.id

### 1.3 Migrations reproductibles & seeds
- Migrations: versionnées dans `db/migrate`, rejouables sur une DB vierge.
- Schéma: `db/schema.rb` suivi en VCS pour reproductibilité.
- Seeds: `db/seeds.rb` idempotent (à enrichir avec un jeu minimal: 1 client, 1 portefeuille, dépôts de test).

## 2) Transactions & rollback
- Les opérations sensibles (ex. dépôt, réservation/libération de fonds, remplacement/annulation d’ordre) sont encapsulées dans des transactions DB.
- Toute exception annule la transaction (rollback) et renvoie une réponse d’erreur JSON normalisée.
- Exemples:
  - UC‑03 (dépôt): insertion transaction + mise à jour solde dans une transaction; idempotence empêche le double crédit.
  - UC‑06 (replace/cancel): ajustement des fonds réservés + update d’ordre atomiques; verrouillage optimiste via `lock_version`.

## 3) Implémentation (DAO/Repository/ORM)
- Pattern Repository avec ActiveRecord (adapters) pour `Client`, `Portfolio`, `Order`, `PortfolioTransaction`, `Trade`.
- Services applicatifs orchestrent la logique, isolant le domaine des détails ORM.
- Tests d’intégration sur DB conteneurisée (GitHub Actions: service `postgres:15-alpine`).

## 4) Idempotence
- Dépôts (implémenté): en‑tête `Idempotency-Key` + contrainte unique `(account_id, idempotency_key)` → 201 (1ère exécution), 200 (rejeu), aucun double crédit.
- Ordres (proposé): introduction d’un champ `client_order_id` (ou `idempotency_key`) unique par `(account_id, client_order_id)` pour éviter les doubles créations involontaires.
  - Migration à prévoir + adaptation du contrôleur `OrdersController#create`.
  - Statut: à planifier (hors périmètre UC‑05 actuel).

## 5) Journal d’audit (append‑only)
- Objectif: tracer les événements métier et techniques sensibles (création d’ordre, remplacement, annulation, dépôt/échec, authentification sensible).
- Modèle proposé: table `audit_events` (id, occurred_at, actor_id, account_id, event_type, entity_type, entity_id, payload JSONB, correlation_id), indexée par `occurred_at`, `account_id`, `event_type`.
- Append‑only:
  - Convention applicative: INSERT‑only, jamais d’UPDATE/DELETE.
  - (Option DB) Trigger qui empêche UPDATE/DELETE et lève une erreur.

## 6) Critères d’acceptation (CA)
- CA‑P1: Migrations appliquées sur une DB vierge sans erreur; schéma reproduit à l’identique.
- CA‑P2: Contraintes d’unicité/idempotence actives (tests d’intégration: violation → erreur attendue).
- CA‑P3: Transactions: dépôt/ordre (création, replace, cancel) garantissent atomicité; rollback vérifié par tests.
- CA‑P4: CRUD robustes sur agrégats clés:
  - Comptes (Clients): create/read/update (email unique) — suppression soft si requis (optionnel).
  - Ordres: create/show/cancel/replace — `lock_version` géré; réservations cohérentes.
  - Positions: cohérence dérivée de `trades` (somme par symbole/sens); documentée, table optionnelle.
- CA‑P5: Audit append‑only: insertion enregistrée pour événements critiques (au minimum design approuvé et table/migration prête).

## 7) Roadmap (technique)
1. Ajouter FKs (migrations non disruptives) + validations référentielles.
2. Enrichir seeds idempotentes (compte de démo + dépôts + 1 ordre).
3. Mettre en place table `audit_events` + triggers anti‑update/delete.
4. Étendre UC‑05 pour l’idempotence des ordres (`client_order_id`).
5. Bench index (EXPLAIN) et ajouter index composites si nécessaires (ex: orders(account_id,status,updated_at)).
