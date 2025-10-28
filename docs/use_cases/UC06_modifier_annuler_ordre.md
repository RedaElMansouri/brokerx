# UC-06 Modifier / Annuler un ordre

> Diagramme UML (séquence): `docs/use_cases/puml/UC06_modifier_annuler_ordre.puml`

Ce cas d'usage permet au client de modifier un ordre en cours (prix, quantité, TIF) et d'annuler un ordre non finalisé. Le verrouillage optimiste via `lock_version` évite les conflits concurrentiels.

## Endpoints

- Modifier (remplacement): `POST /api/v1/orders/:id/replace`
- Annuler (explicite): `POST /api/v1/orders/:id/cancel`
- Rappel utilitaire: récupérer un ordre: `GET /api/v1/orders/:id`

Toutes les requêtes exigent:
- Header `Authorization: Bearer <token>`
- `Content-Type: application/json`

## Modifier un ordre

Request body:
```
{
  "order": {
    "price": 123.45,        // optionnel
    "quantity": 10,         // optionnel, > 0
    "time_in_force": "DAY",// optionnel (DAY|GTC|IOC|FOK)
    "client_version": 3     // requis: version actuelle (lock_version)
  }
}
```

Réponses:
- 200 OK
```
{
  "success": true,
  "id": 42,
  "status": "new",
  "quantity": 10,
  "price": 123.45,
  "time_in_force": "DAY",
  "reserved_amount": 1234.50,
  "lock_version": 4,
  "message": "Order modified"
}
```
- 409 Conflict (version)
```
{ "success": false, "code": "version_conflict", "message": "Order has been modified by another process" }
```
- 422 Unprocessable Content (validation métier)
```
{ "success": false, "errors": ["Insufficient funds"] }
```
- 404 Not Found / 403 Forbidden / 401 Unauthorized

Notes:
- Sur ordre d'achat, les fonds réservés sont ajustés (réservation supplémentaire si le coût augmente, libération si baisse).
- Les règles de validation pré‑trade sont réévaluées.

## Annuler un ordre

Request body:
```
{ "client_version": 4 }
```

Réponses:
- 200 OK
```
{ "success": true, "status": "cancelled", "lock_version": 5, "message": "Order cancelled" }
```
- 409 Conflict / 422 Invalid State / 404 / 403 / 401 idem ci‑dessus.

Effet de bord:
- Sur un achat, les fonds réservés sont libérés.

## Récupérer un ordre

`GET /api/v1/orders/:id`

Réponse 200:
```
{
  "success": true,
  "id": 42,
  "account_id": 7,
  "symbol": "AAPL",
  "order_type": "limit",
  "direction": "buy",
  "quantity": 10,
  "price": 123.45,
  "time_in_force": "DAY",
  "status": "new",
  "reserved_amount": 1234.50,
  "lock_version": 4,
  "created_at": "...",
  "updated_at": "..."
}
```

## Exemples (curl)

Remplacer (prix + quantité):
```
curl -X POST \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"order":{"price":121.0,"quantity":8,"client_version":3}}' \
  http://localhost:3000/api/v1/orders/42/replace
```

Annuler:
```
curl -X POST \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"client_version":4}' \
  http://localhost:3000/api/v1/orders/42/cancel
```
