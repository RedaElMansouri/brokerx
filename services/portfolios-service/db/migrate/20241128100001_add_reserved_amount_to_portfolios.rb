# frozen_string_literal: true

class AddReservedAmountToPortfolios < ActiveRecord::Migration[7.1]
  def change
    add_column :portfolios, :reserved_amount, :decimal, precision: 15, scale: 2, default: 0.0, null: false
  end
end
