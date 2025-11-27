# frozen_string_literal: true

class CreatePortfolios < ActiveRecord::Migration[7.1]
  def change
    create_table :portfolios, id: :uuid do |t|
      t.uuid :client_id, null: false
      t.string :name, null: false
      t.decimal :cash_balance, precision: 15, scale: 2, default: 0.0, null: false
      t.string :currency, limit: 3, default: 'CAD', null: false
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :portfolios, :client_id
    add_index :portfolios, :status
    add_index :portfolios, [:client_id, :status]
  end
end
