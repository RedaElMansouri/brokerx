# DDD Refactor Plan (non-destructive)

This document lists recommended move/delete actions to simplify navigation and prepare for microservice extraction.

## Changes applied

- Controllers colocated under Infrastructure:
  - Moved from `app/controllers/**/*` to `app/infrastructure/web/controllers/**/*`.
  - Autoload configured in `config/initializers/zeitwerk.rb` with `push_dir`.
- Removed duplicate AR models under `app/models` in favor of Infrastructure path:
  - Deleted `app/models/client_record.rb` and `app/models/portfolio_record.rb`.

## Strong recommendations (you can apply safely)

- Keep `app/models/application_record.rb` where it is (Rails convention).

## Nice-to-have follow-ups

- Introduce mappers for AR <-> Domain conversion (keep in `app/infrastructure/persistence/mappers`).
- Establish a code review rule to forbid `ActiveRecord::Base` references in `app/domain` and `app/application` (and optionally a simple static check in CI).
- Create `Application::Contracts` for request/response types if DTOs grow.

## Notes
- Controllers now reference `Application::UseCases` and `Application::Dtos` after this change.
- The `Application` namespace is configured in `config/initializers/zeitwerk.rb`.
