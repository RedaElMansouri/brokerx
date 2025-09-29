class CreatePortfolios < ActiveRecord::Migration[7.1]
  def change
    create_table :portfolios do |t|
      t.uuid :account_id, null: false
      t.string :currency, null: false
      t.decimal :available_balance, precision: 15, scale: 2, default: 0
      t.decimal :reserved_balance, precision: 15, scale: 2, default: 0

      t.timestamps
    end
    add_index :portfolios, :account_id, unique: true
    add_index :portfolios, :currency
  end
end
