# frozen_string_literal: true

# Seeds for orders-service development

puts 'Seeding orders-service development data...'

# Sample client IDs (would come from clients-service)
sample_client_ids = [
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
]

# Create some sample orders
sample_client_ids.each do |client_id|
  # Buy order
  Order.find_or_create_by!(
    client_id: client_id,
    symbol: 'AAPL',
    direction: 'buy',
    order_type: 'limit',
    quantity: 100,
    price: 170.00
  ) do |order|
    order.status = 'working'
    order.time_in_force = 'DAY'
    order.reserved_amount = 17000.00
    puts "Created buy order for client #{client_id}: AAPL @ $170.00"
  end

  # Sell order
  Order.find_or_create_by!(
    client_id: client_id,
    symbol: 'MSFT',
    direction: 'sell',
    order_type: 'limit',
    quantity: 50,
    price: 385.00
  ) do |order|
    order.status = 'working'
    order.time_in_force = 'GTC'
    puts "Created sell order for client #{client_id}: MSFT @ $385.00"
  end
end

puts 'Done seeding orders-service!'
