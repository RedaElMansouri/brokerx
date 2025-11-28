# frozen_string_literal: true

class CreateExecutionReports < ActiveRecord::Migration[7.1]
  def change
    create_table :execution_reports, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :trade, null: true, foreign_key: true, type: :uuid
      t.string :status, null: false
      t.integer :quantity
      t.decimal :price, precision: 15, scale: 4
      t.boolean :processed, default: false, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :execution_reports, :status
    add_index :execution_reports, :processed
    add_index :execution_reports, [:processed, :created_at]
  end
end
