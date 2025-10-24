# App structure (DDD/Hexagonal)

This Rails app is organized by layers and bounded contexts to make navigation simple and ease future microservice extraction.

- Domain (pure business): `app/domain`
  - Namespaced as `Domain::...`
  - Entities, Value Objects, domain services, repository interfaces
  - Organized by bounded contexts (e.g., `clients`, `trading`, etc.)
- Application (use cases): `app/application`
  - Namespaced as `Application::...`
  - Use cases (orchestrate domain), DTOs (input/output), application services
- Infrastructure (adapters): `app/infrastructure`
  - Namespaced as `Infrastructure::...`
  - ActiveRecord models, repository implementations, external clients, mailers, etc.
- Web/API (adapter): `app/controllers` (Rails default)
  - Currently lives in the Rails default path; considered an Infrastructure adapter.
  - Future move: `app/infrastructure/web` (keeping routes updated) if we want full adapter colocation.

Rules of dependency:
- Infrastructure depends on Application and Domain.
- Application depends on Domain.
- Domain depends on nothing (no Rails/ActiveRecord).

Quick “where do I put…?”
- Business rule, entity, VO → `app/domain/<bounded_context>/...`
- Use case/interactor → `app/application/use_cases/*`
- Request/command/response DTO → `app/application/dtos/*`
- Cross-UC app service (validation, orchestrators) → `app/application/services/*`
- DB models & repository impl → `app/infrastructure/persistence/*`
- HTTP controllers/serializers → `app/controllers` (adapter)

Notes for microservice extraction:
- Keep controller → use case → repository boundaries explicit.
- Avoid referencing ActiveRecord in Domain or Application.
- Prefer passing repository interfaces to use cases.
