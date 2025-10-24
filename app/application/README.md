# Application Layer (`Application::`)

Purpose: Coordinate use cases and orchestrate domain operations; define system inputs/outputs independent of transport/UI.

Folders:
- `use_cases/` → one class per use case (Application::UseCases::*)
- `dtos/` → plain data carriers for commands/responses (Application::Dtos::*)
- `services/` → cross-UC app services (e.g., validation, schedulers, orchestrators)

Guidelines:
- Depends on Domain abstractions; do not reference ActiveRecord.
- Accept simple primitives or DTOs; return DTOs/primitives.
- Inject repository interfaces (or adapters via DI from controllers).
