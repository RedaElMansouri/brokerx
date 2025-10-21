class AddAuthFieldsToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :password_digest, :string
    add_column :clients, :mfa_attempts, :integer, default: 0, null: false
    add_column :clients, :last_mfa_attempt_at, :datetime
    add_index :clients, :password_digest
  end
end
