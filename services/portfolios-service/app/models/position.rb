# frozen_string_literal: true

class Position < ApplicationRecord
  belongs_to :portfolio

  validates :symbol, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :average_cost, numericality: { greater_than_or_equal_to: 0 }

  scope :with_holdings, -> { where('quantity > 0') }

  def market_value(current_price = nil)
    price = current_price || average_cost
    quantity * price
  end

  def unrealized_pnl(current_price)
    (current_price - average_cost) * quantity
  end
end
