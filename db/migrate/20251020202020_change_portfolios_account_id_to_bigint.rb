class ChangePortfoliosAccountIdToBigint < ActiveRecord::Migration[7.1]
  def up
    # Safest path: drop and recreate column as bigint (dev/prototype has no critical data)
    remove_index :portfolios, :account_id if index_exists?(:portfolios, :account_id)
    remove_column :portfolios, :account_id
    add_column :portfolios, :account_id, :bigint # allow nulls during transition
    add_index :portfolios, :account_id, unique: true
  end

  def down
    remove_index :portfolios, :account_id if index_exists?(:portfolios, :account_id)
    remove_column :portfolios, :account_id
    add_column :portfolios, :account_id, :uuid
    add_index :portfolios, :account_id, unique: true
  end
end
