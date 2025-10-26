# UC-03 — Dépôt de fonds (idempotent)

## Métadonnées
- Identifiant: UC-03
- Version: 1.0
- Statut: Must‑Have (Phase 2)
- Priorité: Élevée

## Objectif
Permettre au client de créditer son portefeuille par dépôt de fonds, avec idempotence forte pour éviter les doubles crédits en cas de ré‑essais réseaux.

## Acteurs
- Client (authentifié)
- Service Portefeuilles (Repository + AR)

## Préconditions
- Client authentifié (JWT)
- Portefeuille existant pour le compte (monnaie: USD par défaut)

## Postconditions (Succès)
- Transaction de portefeuille (operation_type = deposit) créée en statut `settled`
- Solde disponible ajusté (+ montant)
- Réponse 201 Created sur première exécution (200 OK si re‑jeu idempotent)

## Idempotence
- Clé: en‑tête HTTP `Idempotency-Key` portée par requête, unique par compte.
- Contrainte: index unique partiel `(account_id, idempotency_key)` lorsque `idempotency_key IS NOT NULL`.
- Rejeu: si même clé, la réponse renvoie le même résultat logique sans recréditer, avec code 200 et `success: true`.

## API

### POST /api/v1/deposits
Headers:
- `Authorization: Bearer <token>` (JWT HS256: iss=brokerx, aud=brokerx.web)
- `Content-Type: application/json`
- `Idempotency-Key: <uuid>` (recommandé)

Body:
```json
{ "amount": 1000.0, "currency": "USD" }
```

Réponses:
- 201 Created (nouvelle exécution)
```json
{
  "success": true,
  "status": "settled",
  "transaction_id": 123,
  "balance_after": 1000.0
}
```
- 200 OK (rejeu idempotent)
```json
{
  "success": true,
  "status": "settled",
  "transaction_id": 123,
  "balance_after": 1000.0
}
```
- 401 Unauthorized
```json
{ "success": false, "error": "Unauthorized" }
```
- 422 Unprocessable Content (validation)
```json
{ "success": false, "error": "Amount must be greater than 0" }
```

### GET /api/v1/deposits
- Liste les derniers dépôts du client (limite 20)
- En‑têtes: `Authorization: Bearer <token>`

Réponse 200:
```json
{
  "success": true,
  "deposits": [
    { "id": 123, "amount": 1000.0, "currency": "USD", "status": "settled", "settled_at": "2025-10-25T20:12:34Z" }
  ]
}
```

## Flux (succès)
1. Authentifier la requête (JWT)
2. Extraire `amount`, `currency`, et `Idempotency-Key`
3. Use‑case `DepositFundsUseCase`:
   - Valide le `amount` (> 0)
   - Vérifie/charge le portefeuille
   - Applique idempotence: si clé déjà vue → retourne résultat précédent
   - Crée la transaction (deposit, status=settled) et crédite le portefeuille
4. Contrôleur répond 201 (ou 200 si rejoué) avec `transaction_id` et `balance_after`

## Exceptions
- 401: JWT invalide/absent
- 422: `amount` manquant ou <= 0, `currency` invalide
- 500: Erreur interne (DB, logique)

## Critères d’acceptation
- CA‑03.01: Dépôt 1000.0 → solde disponible +1000.0, statut `settled`, 201
- CA‑03.02: Rejeu même `Idempotency-Key` → 200, aucun double crédit
- CA‑03.03: Sans Authorization → 401
- CA‑03.04: `amount` = 0 → 422

## Sécurité
- JWT signé (HS256), validation iss/aud/exp
- Pas de données sensibles dans la réponse (hors montants/IDs)

## Persistance
- Table `portfolio_transactions` (deposit):
  - Colonnes clés: `account_id`, `amount`, `currency`, `status`, `idempotency_key`, `settled_at`
  - Index unique partiel: `(account_id, idempotency_key)`
- Table `portfolios`: `available_balance` incrémentée

## Références
- `app/infrastructure/web/controllers/api/v1/deposits_controller.rb`
- `app/application/use_cases/deposit_funds_use_case.rb`
- `db/schema.rb` (index unique idempotency)
- Tests: `test/integration/e2e_deposit_funds_test.rb`
