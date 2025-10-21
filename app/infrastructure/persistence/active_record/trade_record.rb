module Infrastructure
  module Persistence
    module ActiveRecord
      class TradeRecord < ::ApplicationRecord
        self.table_name = 'trades'
        validates :order_id, :account_id, :symbol, :quantity, :price, :side, presence: true
        validates :quantity, numericality: { only_integer: true, greater_than: 0 }
        validates :price, numericality: { greater_than: 0 }
        validates :side, inclusion: { in: %w[buy sell] }
      end
    end
  end
end
