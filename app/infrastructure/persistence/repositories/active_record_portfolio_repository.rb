module Infrastructure
  module Persistence
    module Repositories
      class ActiveRecordPortfolioRepository < Domain::Clients::Repositories::PortfolioRepository
        def find(id)
          record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_by(id: id)
          raise Domain::Shared::Repository::RecordNotFound, "Portfolio not found: #{id}" unless record

          Infrastructure::Persistence::Mappers::PortfolioMapper.to_entity(record)
        end

        def find_by_account_id(account_id)
          record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_by(account_id: account_id)
          return nil unless record

          Infrastructure::Persistence::Mappers::PortfolioMapper.to_entity(record)
        end

        def save(portfolio_entity)
          ::ActiveRecord::Base.transaction do
            record = build_or_find_record(portfolio_entity)
            record.assign_attributes(Infrastructure::Persistence::Mappers::PortfolioMapper.to_record_attributes(portfolio_entity))

            unless record.save
              raise Domain::Shared::Repository::Error, "Failed to save portfolio: #{record.errors.full_messages}"
            end

            portfolio_entity.id = record.id
            portfolio_entity
          end
        end

        def reserve_funds(portfolio_id, amount)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.lock.find_by(id: portfolio_id)
            raise Domain::Shared::Repository::RecordNotFound, "Portfolio not found: #{portfolio_id}" unless record

            money_amount = if amount.is_a?(Domain::Clients::ValueObjects::Money)
                             amount
                           else
                             Domain::Clients::ValueObjects::Money.new(
                               amount, record.currency
                             )
                           end

            unless record.available_balance >= money_amount.amount
              raise Domain::Shared::Repository::Error, "Insufficient funds in portfolio: #{portfolio_id}"
            end

            record.available_balance -= money_amount.amount
            record.reserved_balance += money_amount.amount
            record.save!
            Infrastructure::Persistence::Mappers::PortfolioMapper.to_entity(record)
          end
        end

        def release_funds(portfolio_id, amount)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.lock.find_by(id: portfolio_id)
            raise Domain::Shared::Repository::RecordNotFound, "Portfolio not found: #{portfolio_id}" unless record

            money_amount = if amount.is_a?(Domain::Clients::ValueObjects::Money)
                             amount
                           else
                             Domain::Clients::ValueObjects::Money.new(
                               amount, record.currency
                             )
                           end

            unless record.reserved_balance >= money_amount.amount
              raise Domain::Shared::Repository::Error, "Insufficient reserved funds in portfolio: #{portfolio_id}"
            end

            record.reserved_balance -= money_amount.amount
            record.available_balance += money_amount.amount
            record.save!
            Infrastructure::Persistence::Mappers::PortfolioMapper.to_entity(record)
          end
        end

        private

        def build_or_find_record(entity)
          id = entity.id
          if id.is_a?(Integer) || (id.is_a?(String) && id =~ /\A\d+\z/)
            Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_or_initialize_by(id: id)
          else
            # Use natural key on create
            Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_or_initialize_by(account_id: entity.account_id)
          end
        end

        # mapping handled by Infrastructure::Persistence::Mappers::PortfolioMapper
      end
    end
  end
end
