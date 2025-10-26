# Démo bout-en-bout (prototype)

Objectif: démontrer un scénario complet: connexion, dépôt, placement d'ordres, appariement interne, notification.

## Pré-requis
- Serveur lancé (rails server)
- Un compte client d'essai (voir db/seeds.rb si SEED_DEMO activé)

## Étapes

1. Authentification MFA
   - POST /api/v1/auth/login { email, password }
   - Récupérer le code MFA (mail log en dev) et POST /api/v1/auth/verify_mfa { email, code }
   - Sauvegarder le token `Bearer <jwt>`

2. Dépôt (idempotent)
   - POST /api/v1/deposits avec header `Idempotency-Key: <uuid>` et body { amount, currency }
   - 201 lors de la première soumission, 200 en rejeu

3. Placer un ordre d'achat
   - POST /api/v1/orders { order: { symbol: "AAPL", order_type: "limit", direction: "buy", quantity: 1, price: 100.0, client_order_id: "<uuid>" } }
   - Noter `order_id`

4. Placer un ordre de vente opposé (même compte possible dans ce prototype)
   - POST /api/v1/orders { order: { symbol: "AAPL", order_type: "market", direction: "sell", quantity: 1 } }

5. Observation
   - Le moteur d'appariement simple remplit les 2 ordres (status: filled)
   - GET /api/v1/orders/{id} pour vérifier
   - Sur l'UI, une notification ActionCable (OrdersChannel) rafraîchit le panneau d'ordres

6. Portefeuille
   - GET /api/v1/portfolio: vérifier les montants réservés/committed

## Notes
- Les messages temps réel (MarketChannel) incluent des horodatages ISO8601
- Les erreurs sont renvoyées en JSON avec `success:false`, `code`, `message`
