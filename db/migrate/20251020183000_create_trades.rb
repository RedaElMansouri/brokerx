class CreateTrades < ActiveRecord::Migration[7.1]
  def change
    create_table :trades do |t|
      t.bigint :order_id, null: false
      t.bigint :account_id, null: false
      t.string :symbol, null: false
      t.integer :quantity, null: false
      t.decimal :price, precision: 15, scale: 4, null: false, default: 0
      t.string :side, null: false # buy/sell
      t.string :status, null: false, default: 'executed'

      t.timestamps
    end

    add_index :trades, :order_id
    add_index :trades, :account_id
    add_index :trades, :symbol
  end
end
