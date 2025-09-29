module Infrastructure
  module Persistence
    module ActiveRecord
      class PortfolioRecord < ::ApplicationRecord
        self.table_name = 'portfolios'

        validates :account_id, presence: true, uniqueness: true
        validates :currency, presence: true
        validates :available_balance, :reserved_balance, numericality: { greater_than_or_equal_to: 0 }

        before_save :validate_balances

        private

        def validate_balances
          if available_balance < 0 || reserved_balance < 0
            errors.add(:base, "Balances cannot be negative")
            throw :abort
          end
        end
      end
    end
  end
end
