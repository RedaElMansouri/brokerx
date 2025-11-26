# frozen_string_literal: true

class CreateVerificationTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :verification_tokens, id: :uuid do |t|
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.string :token_type, null: false
      t.datetime :expires_at, null: false
      t.boolean :used, default: false, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :verification_tokens, :token, unique: true
    add_index :verification_tokens, [:client_id, :token_type]
  end
end
