class CreatePortfolioTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :portfolio_transactions do |t|
      t.bigint :account_id, null: false
      t.string :operation_type, null: false, default: 'deposit' # deposit, withdrawal, trade, fee
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: 'pending' # pending, settled, failed
      t.string :idempotency_key
      t.string :external_reference
      t.jsonb :metadata, null: false, default: {}
      t.datetime :settled_at
      t.text :failure_reason

      t.timestamps
    end

    add_index :portfolio_transactions, :account_id
    add_index :portfolio_transactions, [:account_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL"
    add_index :portfolio_transactions, :status
  end
end
