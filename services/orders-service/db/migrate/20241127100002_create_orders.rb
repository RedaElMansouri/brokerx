# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders, id: :uuid do |t|
      t.uuid :client_id, null: false
      t.string :symbol, null: false, limit: 10
      t.string :direction, null: false       # buy, sell
      t.string :order_type, null: false      # market, limit
      t.integer :quantity, null: false
      t.decimal :price, precision: 15, scale: 4
      t.string :time_in_force, default: 'DAY', null: false  # DAY, GTC, IOC, FOK
      t.string :status, default: 'new', null: false
      t.integer :filled_quantity, default: 0, null: false
      t.decimal :reserved_amount, precision: 15, scale: 2, default: 0
      t.string :correlation_id
      t.integer :lock_version, default: 0, null: false

      t.timestamps
    end

    add_index :orders, :client_id
    add_index :orders, :symbol
    add_index :orders, :status
    add_index :orders, :direction
    add_index :orders, [:symbol, :direction, :status]
    add_index :orders, :correlation_id
    add_index :orders, :created_at
  end
end
