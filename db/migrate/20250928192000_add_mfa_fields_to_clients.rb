class AddMfaFieldsToClients < ActiveRecord::Migration[7.0]
  def change
    add_column :clients, :mfa_code, :string
    add_column :clients, :mfa_sent_at, :datetime
    add_index :clients, :mfa_code
  end
end
