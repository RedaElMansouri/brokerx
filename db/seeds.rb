# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Minimal demo data (idempotent)
if ENV["SEED_DEMO"] == "1"
	client = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_or_create_by!(
		email: 'demo@brokerx.local'
	) do |c|
		c.first_name = 'Demo'
		c.last_name = 'User'
		c.date_of_birth = '1990-01-01'
		c.status = 'active'
		c.password = 'secret'
	end

	portfolio = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.find_or_create_by!(account_id: client.id) do |p|
		p.currency = 'USD'
		p.available_balance = 10000.0
		p.reserved_balance = 0.0
	end

	# One settled deposit via transaction record if not exist
	unless Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.exists?(account_id: client.id, idempotency_key: 'seed-demo-1')
		Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.create!(
			account_id: client.id,
			operation_type: 'deposit', amount: 1000.0, currency: 'USD', status: 'settled', idempotency_key: 'seed-demo-1', settled_at: Time.current
		)
		portfolio.update!(available_balance: portfolio.available_balance + 1000.0)
	end
end
