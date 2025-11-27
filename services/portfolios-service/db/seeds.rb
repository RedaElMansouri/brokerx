# frozen_string_literal: true

# Seeds for portfolios-service development

puts 'Seeding portfolios-service development data...'

# Note: Portfolios are created when clients make their first deposit
# or explicitly create a portfolio. The client_id references the
# clients-service database.

# For testing, create some sample portfolios with known UUIDs
sample_client_ids = [
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000003'
]

sample_client_ids.each_with_index do |client_id, index|
  portfolio = Portfolio.find_or_create_by!(client_id: client_id) do |p|
    p.name = "Portfolio #{index + 1}"
    p.currency = 'CAD'
    p.cash_balance = 10_000.0 * (index + 1)
    p.status = 'active'
  end

  puts "Created portfolio: #{portfolio.name} for client #{client_id} with balance $#{portfolio.cash_balance}"

  # Create some sample transactions
  if portfolio.portfolio_transactions.empty?
    portfolio.portfolio_transactions.create!(
      transaction_type: 'deposit',
      amount: portfolio.cash_balance,
      currency: 'CAD',
      status: 'completed',
      idempotency_key: "seed-deposit-#{client_id}",
      processed_at: Time.current
    )
    puts "  - Created initial deposit transaction"
  end
end

puts 'Done seeding portfolios-service!'
