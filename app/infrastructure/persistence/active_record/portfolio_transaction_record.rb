module Infrastructure
  module Persistence
    module ActiveRecord
      class PortfolioTransactionRecord < ::ApplicationRecord
        self.table_name = 'portfolio_transactions'

        enum :operation_type, { deposit: 'deposit', withdrawal: 'withdrawal', trade: 'trade', fee: 'fee' }
        enum :status, { pending: 'pending', settled: 'settled', failed: 'failed' }

        validates :account_id, :operation_type, :amount, :currency, :status, presence: true
        validates :amount, numericality: { greater_than: 0 }

        before_validation do
          self.currency = currency&.upcase
        end
      end
    end
  end
end
