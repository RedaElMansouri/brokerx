# frozen_string_literal: true

class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false

      # Email verification
      t.boolean :email_verified, default: false, null: false
      t.datetime :email_verified_at

      # MFA
      t.boolean :mfa_enabled, default: false, null: false

      # Security
      t.integer :failed_attempts, default: 0, null: false
      t.datetime :locked_at

      t.timestamps
    end

    add_index :clients, :email, unique: true
    add_index :clients, :email_verified
  end
end
