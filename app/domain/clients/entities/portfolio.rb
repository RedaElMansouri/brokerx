module Domain
  module Clients
    module Entities
      class Portfolio < Domain::Shared::Entity
        attr_reader :account_id, :currency, :available_balance, :reserved_balance

        def initialize(account_id:, currency: 'USD', available_balance: 0, reserved_balance: 0, **kwargs)
          super(**kwargs)
          @account_id = account_id
          @currency = currency
          @available_balance = ValueObjects::Money.new(available_balance, currency)
          @reserved_balance = ValueObjects::Money.new(reserved_balance, currency)

          validate!
        end

        def total_balance
          available_balance.add(reserved_balance)
        end

        def credit(amount)
          money_amount = amount.is_a?(ValueObjects::Money) ? amount : ValueObjects::Money.new(amount, currency)
          @available_balance = available_balance.add(money_amount)
          touch
        end

        def debit(amount)
          money_amount = amount.is_a?(ValueObjects::Money) ? amount : ValueObjects::Money.new(amount, currency)
          @available_balance = available_balance.subtract(money_amount)
          touch
        end

        def reserve(amount)
          money_amount = amount.is_a?(ValueObjects::Money) ? amount : ValueObjects::Money.new(amount, currency)
          @available_balance = available_balance.subtract(money_amount)
          @reserved_balance = reserved_balance.add(money_amount)
          touch
        end

        def release(amount)
          money_amount = amount.is_a?(ValueObjects::Money) ? amount : ValueObjects::Money.new(amount, currency)
          @available_balance = available_balance.add(money_amount)
          @reserved_balance = reserved_balance.subtract(money_amount)
          touch
        end

        def sufficient_funds?(amount)
          money_amount = amount.is_a?(ValueObjects::Money) ? amount : ValueObjects::Money.new(amount, currency)
          available_balance.amount >= money_amount.amount
        end

        private

        def validate!
          raise "Account ID is required" if account_id.nil?
          raise "Currency is required" if currency.nil? || currency.empty?
        end
      end
    end
  end
end
