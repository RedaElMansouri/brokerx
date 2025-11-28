# frozen_string_literal: true

class CreateTrades < ActiveRecord::Migration[7.1]
  def change
    create_table :trades, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.string :symbol, null: false, limit: 10
      t.string :direction, null: false
      t.integer :quantity, null: false
      t.decimal :price, precision: 15, scale: 4, null: false
      t.uuid :counterparty_order_id
      t.datetime :executed_at, null: false

      t.timestamps
    end

    add_index :trades, :symbol
    add_index :trades, :executed_at
    add_index :trades, :counterparty_order_id
  end
end
