class CreatePositions < ActiveRecord::Migration[7.1]
  def change
    create_table :positions, id: :uuid do |t|
      t.uuid :portfolio_id, null: false
      t.string :symbol, null: false
      t.decimal :quantity, precision: 15, scale: 4, null: false, default: 0
      t.decimal :average_cost, precision: 15, scale: 4, null: false, default: 0
      t.timestamps
    end

    add_index :positions, :portfolio_id
    add_index :positions, [:portfolio_id, :symbol], unique: true
    add_index :positions, :symbol
    add_foreign_key :positions, :portfolios
  end
end
