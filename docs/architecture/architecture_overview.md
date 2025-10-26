# Architecture Overview - BrokerX+

## Vision architecturale
Architecture monolithique hexagonale organisée par bounded contexts, préparant la migration vers les microservices.

## Principes architecturaux
1. **Separation of Concerns** : Domaine métier isolé de l'infrastructure
2. **Domain-Driven Design** : Structure alignée sur les bounded contexts
3. **Testability** : Couplage faible permettant des tests unitaires purs
4. **Evolutionary Architecture** : Préparation pour la migration microservices

## Structure des couches
```
brokerx/
├── app/
│ ├── domain/ # Couche Domaine (Entities, Value Objects, Domain Services)
│ │ ├── clients/ # Bounded Context: Client & Comptes
│ │ ├── trading/ # Bounded Context: Ordres & Trading
│ │ └── market_data/ # Bounded Context: Marché & Données
│ ├── application/ # Couche Application (Use Cases, Services)
│ │ ├── use_cases/ # Implémentation des UC
│ │ └── services/ # Services applicatifs
│ └── infrastructure/ # Couche Infrastructure (Adapters)
│ ├── web/ # Contrôleurs Rails, Serializers
│ ├── persistence/ # ActiveRecord Models, Repositories
│ └── external/ # Clients services externes
├── config/ # Configuration Rails
└── spec/ # Tests (unit, integration, features)
```

## Flux de dépendances
Infrastructure → Application → Domain
↑ ↑ ↑
Frameworks Use Cases Business Rules
↑ ↑ ↑
Rails API Services Entities/VOs

**Aucune dépendance inverse n'est permise** : Le domaine ne connaît pas l'application qui ne connaît pas l'infrastructure.

## Technologies choisies (implémentation actuelle)
- Framework Web: Ruby on Rails 7.1 (API + ActionCable)
- Auth: JWT (HS256, iss=brokerx, aud=brokerx.web)
- Base de données: PostgreSQL 14+
- Persistance: ActiveRecord + Repositories (ports/adapters)
- Temps réel: ActionCable (WebSocket) + simulateur de marché en dev, fallback WS côté UI
- Testing: Minitest + SimpleCov (garde de couverture configurable via CRITICAL_MIN_COVERAGE)
- Conteneurisation: Docker, Docker Compose
- CI/CD: GitHub Actions

### Contrat d'API et documentation
- Contrat OpenAPI 3.1 publié: `/openapi.yaml`
- Swagger UI (statique) : `/swagger.html` (bouton Authorize → JWT Bearer)
- CI: lint/validation automatique de `public/openapi.yaml` (échec pipeline si invalide)

## Évolutions Phase 2 (résumé)
- UC‑03: Dépôts idempotents via en-tête Idempotency-Key (index unique par compte)
- UC‑04: Flux temps réel MarketChannel avec authentification JWT et composant UI sur la page Ordres
- UC‑05: Placement d’ordres avec validations pré‑trade et réservation de fonds pour ACHAT
- UC‑06: Modification/Annulation avec verrouillage optimiste (lock_version) et ajustement de `reserved_amount`