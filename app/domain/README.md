# Domain Layer (`Domain::`)

Purpose: Express business concepts and rules with no framework/DB concerns.

Structure:
- `shared/` base abstractions (`Entity`, `ValueObject`, `Repository`)
- `<bounded_context>/entities/` domain entities
- `<bounded_context>/value_objects/` immutable types
- `<bounded_context>/repositories/` repository interfaces (ports)

Guidelines:
- No ActiveRecord or Rails dependencies.
- Validate invariants in constructors/factory methods.
- Prefer explicit domain errors.
- Keep aggregate boundaries clear; repository interfaces operate on aggregates.
