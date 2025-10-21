class EnforceNotNullOnPortfoliosAccountId < ActiveRecord::Migration[7.1]
  def up
    # Remove any orphan/invalid rows, then apply NOT NULL
    execute "DELETE FROM portfolios WHERE account_id IS NULL;"
    change_column_null :portfolios, :account_id, false
  end

  def down
    change_column_null :portfolios, :account_id, true
  end
end
