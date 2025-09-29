module Domain
  module Clients
    module ValueObjects
      class Money < Domain::Shared::ValueObject
        attr_reader :amount, :currency

        def initialize(amount, currency = 'USD')
          raise ArgumentError, "Amount must be positive" unless amount >= 0
          @amount = BigDecimal(amount.to_s)
          @currency = currency.upcase
        end

        def add(other)
          validate_same_currency(other)
          Money.new(amount + other.amount, currency)
        end

        def subtract(other)
          validate_same_currency(other)
          raise ArgumentError, "Insufficient funds" if amount < other.amount
          Money.new(amount - other.amount, currency)
        end

        def zero?
          amount.zero?
        end

        def positive?
          amount > 0
        end

        def to_s
          "#{format('%.2f', amount)} #{currency}"
        end

        private

        def validate_same_currency(other)
          return if currency == other.currency
          raise ArgumentError, "Currency mismatch: #{currency} vs #{other.currency}"
        end
      end
    end
  end
end
