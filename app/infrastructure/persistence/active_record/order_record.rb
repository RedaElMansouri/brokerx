module Infrastructure
  module Persistence
    module ActiveRecord
      class OrderRecord < ::ApplicationRecord
        self.table_name = 'orders'

        enum :direction, { buy: 'buy', sell: 'sell' }
        validates :order_type, inclusion: { in: %w[market limit] }

        validates :account_id, :symbol, :order_type, :direction, :quantity, presence: true
        validates :quantity, numericality: { only_integer: true, greater_than: 0 }
        validates :price, numericality: { greater_than: 0 }, allow_nil: true
        validates :time_in_force, inclusion: { in: %w[DAY GTC IOC FOK] }
        validates :status, inclusion: { in: %w[new working filled cancelled] }
        validates :client_order_id, length: { maximum: 255 }, allow_nil: true

        before_validation do
          self.symbol = symbol&.upcase
        end
      end
    end
  end
end
