class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.bigint :account_id, null: false
      t.string :symbol, null: false
      t.string :order_type, null: false # 'market' or 'limit'
      t.string :direction, null: false # 'buy' or 'sell'
      t.integer :quantity, null: false
      t.decimal :price, precision: 15, scale: 4
      t.string :time_in_force, null: false, default: 'DAY'
      t.string :status, null: false, default: 'new' # new, working, filled, cancelled
      t.decimal :reserved_amount, precision: 15, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :orders, :account_id
    add_index :orders, :symbol
    add_index :orders, :status
  end
end
