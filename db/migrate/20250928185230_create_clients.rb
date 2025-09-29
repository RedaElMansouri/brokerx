class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.string :email, null: false
      t.string :phone
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.date :date_of_birth, null: false
      t.string :status, null: false, default: 'pending'
      t.string :verification_token
      t.datetime :verified_at

      t.timestamps
    end
    add_index :clients, :email, unique: true
    add_index :clients, :verification_token
    add_index :clients, :status
  end
end
