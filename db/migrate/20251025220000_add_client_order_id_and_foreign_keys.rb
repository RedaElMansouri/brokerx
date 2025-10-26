class AddClientOrderIdAndForeignKeys < ActiveRecord::Migration[7.1]
  def change
    # Idempotence côté ordres (optionnelle à l'appel)
    add_column :orders, :client_order_id, :string
    add_index :orders, [:account_id, :client_order_id], unique: true, where: "client_order_id IS NOT NULL", name: "index_orders_on_account_and_client_order_id_unique"

    # Clés étrangères (référentielles)
    add_foreign_key :orders, :clients, column: :account_id
    add_foreign_key :portfolios, :clients, column: :account_id
    add_foreign_key :portfolio_transactions, :clients, column: :account_id
    add_foreign_key :trades, :orders, column: :order_id
    add_foreign_key :trades, :clients, column: :account_id
  end
end
