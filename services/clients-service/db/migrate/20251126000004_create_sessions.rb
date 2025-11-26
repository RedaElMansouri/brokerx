# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.string :session_type, null: false, default: 'authenticated'
      t.datetime :expires_at, null: false
      t.boolean :revoked, default: false, null: false
      t.datetime :revoked_at
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, [:client_id, :session_type]
  end
end
