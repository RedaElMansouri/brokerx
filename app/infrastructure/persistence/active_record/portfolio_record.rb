module Infrastructure
  module Persistence
    module ActiveRecord
      class PortfolioRecord < ::ApplicationRecord
        self.table_name = 'portfolios'

        validates :account_id, presence: true, uniqueness: true
        validates :currency, presence: true
        validates :available_balance, :reserved_balance, numericality: { greater_than_or_equal_to: 0 }

        before_save :validate_balances
        after_commit :invalidate_cache!

        private

        def validate_balances
          if available_balance < 0 || reserved_balance < 0
            errors.add(:base, "Balances cannot be negative")
            throw :abort
          end
        end

        def invalidate_cache!
          # Remove cached portfolio after any change (create/update) to ensure freshness
          key = "portfolio:#{account_id}:v1"
          Rails.cache.delete(key)
        rescue => e
          Rails.logger.warn("[Cache] failed to invalidate #{key}: #{e.class}: #{e.message}")
        end
      end
    end
  end
end
