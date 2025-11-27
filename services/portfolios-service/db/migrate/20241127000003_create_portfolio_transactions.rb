# frozen_string_literal: true

class CreatePortfolioTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :portfolio_transactions, id: :uuid do |t|
      t.references :portfolio, null: false, foreign_key: true, type: :uuid
      t.string :transaction_type, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :currency, limit: 3, default: 'CAD', null: false
      t.string :status, default: 'pending', null: false
      t.string :idempotency_key, null: false
      t.datetime :processed_at
      t.string :failure_reason

      t.timestamps
    end

    # Unique index for idempotency within a portfolio
    add_index :portfolio_transactions, [:portfolio_id, :idempotency_key], unique: true, name: 'idx_portfolio_transactions_idempotency'
    add_index :portfolio_transactions, :transaction_type
    add_index :portfolio_transactions, :status
    add_index :portfolio_transactions, :idempotency_key
    add_index :portfolio_transactions, :created_at
  end
end
