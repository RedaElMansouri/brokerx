# frozen_string_literal: true

class CreateMfaCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :mfa_codes, id: :uuid do |t|
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.string :code, null: false, limit: 6
      t.datetime :expires_at, null: false
      t.boolean :used, default: false, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :mfa_codes, [:client_id, :code]
  end
end
