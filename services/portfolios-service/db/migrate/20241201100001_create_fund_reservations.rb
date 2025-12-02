class CreateFundReservations < ActiveRecord::Migration[7.1]
  def change
    create_table :fund_reservations, id: :uuid do |t|
      t.uuid :portfolio_id, null: false
      t.uuid :order_id, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :status, null: false, default: 'reserved' # reserved, settled, released
      t.decimal :settled_amount, precision: 15, scale: 2
      t.string :correlation_id
      t.timestamps
    end

    add_index :fund_reservations, :portfolio_id
    add_index :fund_reservations, :order_id, unique: true
    add_index :fund_reservations, :status
    add_index :fund_reservations, :correlation_id
    add_foreign_key :fund_reservations, :portfolios
  end
end
