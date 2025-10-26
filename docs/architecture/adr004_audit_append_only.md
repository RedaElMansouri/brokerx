# ADR 004: Journal d’audit append-only

## Statut
**Proposé** | **Date**: 2025-10-25 | **Décideurs**: Architecte logiciel

## Contexte
Le système manipule des opérations financières (dépôts, réservations, ordres, trades) qui exigent traçabilité et auditabilité fortes. Un journal d’audit append-only garantit l’intégrité des traces et facilite les enquêtes.

## Décision
Mettre en place une table d’événements d’audit en écriture seule, consultable par horodatage et clés métier.

### Modèle
- Table `audit_events`:
  - `id` (PK), `occurred_at` (timestamptz, default now())
  - `actor_id` (nullable), `account_id` (nullable)
  - `event_type` (string, ex: order.created, order.replaced, order.cancelled, deposit.settled)
  - `entity_type` (string), `entity_id` (bigint)
  - `payload` (jsonb), `correlation_id` (uuid/string)
- Index: `(occurred_at)`, `(account_id, occurred_at)`, `(event_type, occurred_at)`

### Append-only (protection)
- Convention applicative: aucun UPDATE/DELETE autorisé.
- Option BD: déclencheurs (BEFORE UPDATE/DELETE) qui lèvent une exception.

### Émission d’événements (exemples)
- UC‑05: `order.created` après persistance + envoi au matching engine
- UC‑06: `order.replaced`/`order.cancelled` (avec `old_values`/`new_values`)
- UC‑03: `deposit.settled` avec `idempotency_key` et `transaction_id`

## Alternatives considérées
- Logs applicatifs uniquement: non structuré et fragile pour la conformité
- Event Sourcing complet: trop coûteux pour le scope actuel

## Conséquences
- (+) Traçabilité réglementaire
- (+) Débogage et analyses post‑incident
- (±) Coût stockage supplémentaire (modéré, compressible)

## Plan d’implémentation
1. Migration `create_audit_events` + index
2. Déclencheurs DB `prevent_update_delete_on_audit_events`
3. Helpers applicatifs pour publier des événements d’audit
4. Intégration progressive dans UC‑03/05/06
