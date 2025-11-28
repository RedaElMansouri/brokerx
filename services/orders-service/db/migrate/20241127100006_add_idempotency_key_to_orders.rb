# frozen_string_literal: true

class AddIdempotencyKeyToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :idempotency_key, :string
    add_index :orders, [:client_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL"
  end
end
