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

        def save(portfolio_entity)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_or_initialize_by(id: portfolio_entity.id)
            record.assign_attributes(map_to_record(portfolio_entity))

            if record.save
              portfolio_entity.id = record.id
              portfolio_entity
            else
              raise Domain::Shared::Repository::Error, "Failed to save portfolio: #{record.errors.full_messages}"
            end
          end
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
