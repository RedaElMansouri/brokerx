# API BrokerX (Phase 2)

- Swagger UI: /swagger.html
- OpenAPI: /openapi.yaml
- Auth: JWT Bearer
  - iss: brokerx
  - aud: brokerx.web
  - alg: HS256

## Endpoints couverts

- Auth:
  - POST /api/v1/auth/login (MFA requis)
  - POST /api/v1/auth/verify_mfa (retourne token)
- Portefeuille:
  - POST /api/v1/deposits (Idempotency-Key)
  - GET /api/v1/deposits
  - GET /api/v1/portfolio
- Ordres:
  - POST /api/v1/orders (client_order_id optionnel pour idempotence)
  - GET /api/v1/orders/{id}
  - POST /api/v1/orders/{id}/replace (client_version)
  - POST /api/v1/orders/{id}/cancel (client_version)

## Sécurité minimale

- CORS activé pour localhost (see config/initializers/cors.rb)
- Authentification JWT sur endpoints protégés
- Validation et assainissement des entrées côté serveur
- Erreurs normalisées JSON (voir ADR-003)

## CI

- Lint OpenAPI dans CI. Le fichier public/openapi.yaml doit rester valide.

