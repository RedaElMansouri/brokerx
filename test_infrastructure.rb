# test_infrastructure.rb
puts "Testing Infrastructure Layer..."

begin
  # Charger manuellement tous les fichiers nécessaires
  load 'app/domain/shared/value_object.rb'
  load 'app/domain/shared/entity.rb'
  load 'app/domain/shared/repository.rb'
  load 'app/domain/clients/value_objects/email.rb'
  load 'app/domain/clients/value_objects/money.rb'
  load 'app/domain/clients/entities/client.rb'
  load 'app/domain/clients/entities/portfolio.rb'
  load 'app/domain/clients/repositories/client_repository.rb'
  load 'app/domain/clients/repositories/portfolio_repository.rb'
  load 'app/models/client_record.rb'
  load 'app/models/portfolio_record.rb'
  load 'app/infrastructure/persistence/repositories/active_record_client_repository.rb'
  load 'app/infrastructure/persistence/repositories/active_record_portfolio_repository.rb'

  # Initialiser les repositories
  client_repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
  portfolio_repo = Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new

  # Test 1: Créer et sauvegarder un client
  puts "1. Testing Client Repository..."
  unique_email = "test+#{SecureRandom.uuid}@example.com"
  client = Domain::Clients::Entities::Client.new(
    email: unique_email,
    first_name: "John",
    last_name: "Doe",
    date_of_birth: Date.new(1990, 1, 1)
  )

  saved_client = client_repo.save(client)
  puts "✓ Client saved with ID: #{saved_client.id}"

  # Test 2: Rechercher le client par email
  found_client = client_repo.find_by_email(unique_email)
  puts "✓ Client found: #{found_client.full_name}"

  # Test 3: Créer un portfolio
  puts "2. Testing Portfolio Repository..."
  portfolio = Domain::Clients::Entities::Portfolio.new(
    account_id: saved_client.id, # Utiliser l'ID du client comme account_id pour le test
    currency: 'USD',
    available_balance: 10000.00,
    reserved_balance: 0.00
  )

  saved_portfolio = portfolio_repo.save(portfolio)
  puts "✓ Portfolio saved with ID: #{saved_portfolio.id}"

  # Test 4: Réserver des fonds
  reserved_portfolio = portfolio_repo.reserve_funds(saved_portfolio.id, 1000.00)
  puts "✓ Funds reserved: #{reserved_portfolio.available_balance} available, #{reserved_portfolio.reserved_balance} reserved"

  puts "🎉 All infrastructure tests passed!"

rescue => e
  puts "❌ Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end
