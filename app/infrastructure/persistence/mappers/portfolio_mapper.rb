module Infrastructure
  module Persistence
    module Mappers
      module PortfolioMapper
        module_function

        def to_entity(record)
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

        def to_record_attributes(entity)
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
