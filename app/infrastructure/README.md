# Infrastructure Layer (`Infrastructure::`)

Purpose: Technical details and adapters for the outside world.

Common subfolders:
- `persistence/` → ActiveRecord models (`ActiveRecord::Base`), repository implementations
- `external/` → HTTP clients, queues, 3rd-party integrations
- `web/` → (optional) HTTP controllers/serializers if you decide to colocate web adapters under infrastructure

Guidelines:
- Convert between ActiveRecord records and Domain entities via mappers.
- Keep ACID/transactions here; expose clean methods to Application layer.
- Controllers should resolve Application use cases and repositories; avoid putting business logic in controllers.
