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

## Technologies choisies
- **Framework Web** : Ruby on Rails 7+ (API Mode)
- **Base de données** : PostgreSQL 14+
- **Testing** : RSpec, FactoryBot, Capybara
- **Conteneurisation** : Docker, Docker Compose
- **CI/CD** : GitHub Actions