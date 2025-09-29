# Implémentation du Repository Pattern

## Overview
Implémentation du pattern Repository pour abstraire la persistance du domaine, utilisant ActiveRecord comme implémentation sous-jacente.

## Structure des Repositories

# Implémentation du Repository Pattern

## Overview
Le pattern Repository encapsule l’accès aux données pour le domaine. Ici, les interfaces vivent dans le domaine et les implémentations concrètes dans l’infrastructure (ActiveRecord). On garde ainsi un domaine pur, testable et indépendant de la technologie de persistance.

## Structure et contrat

### Contrat de base (domaine)
Extrait réel du projet (chemin: `app/domain/shared/repository.rb`). Le contrat est minimal; chaque repository spécifique précise ses opérations.

```ruby
module Domain
  module Shared
    module Repository
      class Error < StandardError; end
      class RecordNotFound < Error; end

      class BaseRepository
      end
    end
  end
end
```

### Interfaces de domaine (clients et portefeuilles)
Les interfaces ne dépendent pas d’ActiveRecord et définissent les opérations nécessaires au domaine.

```ruby
# app/domain/clients/repositories/client_repository.rb
module Domain
  module Clients
    module Repositories
      class ClientRepository < Domain::Shared::Repository::BaseRepository
        def find_by_email(email); raise NotImplementedError; end
        def find_by_verification_token(token); raise NotImplementedError; end
        def find_active_clients; raise NotImplementedError; end
      end
    end
  end
end
```

```ruby
# app/domain/clients/repositories/portfolio_repository.rb
module Domain
  module Clients
    module Repositories
      class PortfolioRepository < Domain::Shared::Repository::BaseRepository
        def find_by_account_id(account_id); raise NotImplementedError; end
        def update_balance(portfolio_id, available_balance, reserved_balance); raise NotImplementedError; end
        def reserve_funds(portfolio_id, amount); raise NotImplementedError; end
        def release_funds(portfolio_id, amount); raise NotImplementedError; end
      end
    end
  end
end
```

## Implémentations ActiveRecord (infrastructure)

Les classes d’infrastructure réalisent les interfaces en s’appuyant sur les modèles ActiveRecord namespacés `Infrastructure::Persistence::ActiveRecord`.

### Clients
Chemin: `app/infrastructure/persistence/repositories/active_record_client_repository.rb`

```ruby
module Infrastructure
  module Persistence
    module Repositories
      class ActiveRecordClientRepository < Domain::Clients::Repositories::ClientRepository
        def find(id)
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(id: id)
          raise Domain::Shared::Repository::RecordNotFound, "Client not found: #{id}" unless record
          map_to_entity(record)
        end

        def find_by_email(email)
          email_value = email.is_a?(Domain::Clients::ValueObjects::Email) ? email.value : email
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(email: email_value)
          return nil unless record
          map_to_entity(record)
        end

        def save(client_entity)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_or_initialize_by(id: client_entity.id)
            record.assign_attributes(map_to_record(client_entity))

            if record.save
              client_entity.id = record.id if client_entity.id.nil?
              client_entity
            else
              raise Domain::Shared::Repository::Error, "Failed to save client: #{record.errors.full_messages}"
            end
          end
        end

        private

        def map_to_entity(record)
          Domain::Clients::Entities::Client.new(
            id: record.id,
            email: Domain::Clients::ValueObjects::Email.new(record.email),
            first_name: record.first_name,
            last_name: record.last_name,
            date_of_birth: record.date_of_birth,
            status: record.status.to_sym,
            verification_token: record.verification_token,
            verified_at: record.verified_at,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def map_to_record(entity)
          {
            email: entity.email.value,
            first_name: entity.first_name,
            last_name: entity.last_name,
            date_of_birth: entity.date_of_birth,
            status: entity.status.to_s,
            verification_token: entity.verification_token,
            verified_at: entity.verified_at
          }
        end
      end
    end
  end
end
```

### Portefeuilles
Chemin: `app/infrastructure/persistence/repositories/active_record_portfolio_repository.rb`

```ruby
module Infrastructure
  module Persistence
    module Repositories
      class ActiveRecordPortfolioRepository < Domain::Clients::Repositories::PortfolioRepository
        def find(id)
          record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_by(id: id)
          raise Domain::Shared::Repository::RecordNotFound, "Portfolio not found: #{id}" unless record
          map_to_entity(record)
        end

        def find_by_account_id(account_id)
          record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_by(account_id: account_id)
          return nil unless record
          map_to_entity(record)
        end

        def reserve_funds(portfolio_id, amount)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.lock.find_by(id: portfolio_id)
            raise Domain::Shared::Repository::RecordNotFound, "Portfolio not found: #{portfolio_id}" unless record

            money_amount = amount.is_a?(Domain::Clients::ValueObjects::Money) ? amount : Domain::Clients::ValueObjects::Money.new(amount, record.currency)

            if record.available_balance >= money_amount.amount
              record.available_balance -= money_amount.amount
              record.reserved_balance += money_amount.amount
              record.save!
              map_to_entity(record)
            else
              raise Domain::Shared::Repository::Error, "Insufficient funds in portfolio: #{portfolio_id}"
            end
          end
        end

        def release_funds(portfolio_id, amount)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.lock.find_by(id: portfolio_id)
            raise Domain::Shared::Repository::RecordNotFound, "Portfolio not found: #{portfolio_id}" unless record

            money_amount = amount.is_a?(Domain::Clients::ValueObjects::Money) ? amount : Domain::Clients::ValueObjects::Money.new(amount, record.currency)

            if record.reserved_balance >= money_amount.amount
              record.reserved_balance -= money_amount.amount
              record.available_balance += money_amount.amount
              record.save!
              map_to_entity(record)
            else
              raise Domain::Shared::Repository::Error, "Insufficient reserved funds in portfolio: #{portfolio_id}"
            end
          end
        end

        private

        def map_to_entity(record)
          Domain::Clients::Entities::Portfolio.new(
            id: record.id,
            account_id: record.account_id,
            currency: record.currency,
            available_balance: record.available_balance,
            reserved_balance: record.reserved_balance,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def map_to_record(entity)
          {
            account_id: entity.account_id,
            currency: entity.currency,
            available_balance: entity.available_balance.amount,
            reserved_balance: entity.reserved_balance.amount
          }
        end
      end
    end
  end
end
```

## Mappage Entité ↔ Record
- `map_to_entity` construit des entités du domaine à partir des records AR.
- `map_to_record` projette l’entité vers un hash d’attributs ActiveRecord.

Cela maintient le domaine indépendant des détails de persistance (types, colonnes, callbacks).

## Transactions et cohérence
- Les méthodes d’écriture utilisent `ActiveRecord::Base.transaction` pour garantir l’atomicité.
- Les opérations de débit/crédit utilisent `lock` pour prévenir les conditions de course lors des réservations de fonds.
- En cas d’échec, des exceptions de domaine sont levées: `Domain::Shared::Repository::Error` ou `RecordNotFound`.

## Utilisation dans les cas d’usage
Extrait du cas d’usage d’inscription montrant l’injection des repositories et leur utilisation.

```ruby
# app/application/use_cases/register_client_use_case.rb
module Application
  module UseCases
    class RegisterClientUseCase
      def initialize(client_repository, portfolio_repository)
        @client_repository = client_repository
        @portfolio_repository = portfolio_repository
      end

      def execute(dto)
        existing_client = @client_repository.find_by_email(dto.email)
        raise "Email already exists" if existing_client

        client = Domain::Clients::Entities::Client.new(
          email: dto.email,
          first_name: dto.first_name,
          last_name: dto.last_name,
          date_of_birth: dto.date_of_birth,
          verification_token: SecureRandom.hex(20)
        )

        saved_client = @client_repository.save(client)

        portfolio = Domain::Clients::Entities::Portfolio.new(
          account_id: saved_client.id,
          currency: 'USD',
          available_balance: 0,
          reserved_balance: 0
        )

        @portfolio_repository.save(portfolio)
        { client: saved_client, verification_token: client.verification_token }
      end
    end
  end
end
```

## Tests et bonnes pratiques
- Testez les repositories comme des unités d’infrastructure en seeds contrôlés (DB de test), en vérifiant:
  - les erreurs levées (`RecordNotFound`, `Error`),
  - les transactions (échec de validation n’écrit rien),
  - les conversions entité/record.
- Les cas d’usage se testent avec des doubles/faux repositories pour isoler la logique applicative.

## Remarques
- Évitez les doublons de classes ActiveRecord sous le même namespace (source d’erreurs `superclass mismatch`).
- Les interfaces de domaine peuvent évoluer (ex: implémenter `find_active_clients`) sans impacter la logique du domaine tant que le contrat reste stable.

Cette implémentation fournit une séparation nette entre domaine et infrastructure, facilitant la testabilité et une future évolution (changement d’ORM ou de source de données) sans toucher au cœur du métier.


