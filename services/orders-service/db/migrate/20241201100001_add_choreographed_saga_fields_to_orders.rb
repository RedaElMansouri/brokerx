class AddChoreographedSagaFieldsToOrders < ActiveRecord::Migration[7.1]
  def change
    # Add pending_funds status and estimated_cost for choreographed saga
    add_column :orders, :estimated_cost, :decimal, precision: 15, scale: 2 unless column_exists?(:orders, :estimated_cost)
    add_column :orders, :rejection_reason, :string unless column_exists?(:orders, :rejection_reason)
    
    # Add index for status queries
    add_index :orders, :status unless index_exists?(:orders, :status)
    add_index :orders, :correlation_id unless index_exists?(:orders, :correlation_id)
  end
end
