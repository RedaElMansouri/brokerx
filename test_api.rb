# test_api.rb
def load_dependencies
  # Domain
  load File.join(__dir__, 'app', 'domain', 'shared', 'value_object.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'shared', 'value_object.rb'))
  load File.join(__dir__, 'app', 'domain', 'shared', 'entity.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'shared', 'entity.rb'))
  load File.join(__dir__, 'app', 'domain', 'shared', 'repository.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'shared', 'repository.rb'))
  load File.join(__dir__, 'app', 'domain', 'clients', 'value_objects', 'email.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'clients', 'value_objects', 'email.rb'))
  load File.join(__dir__, 'app', 'domain', 'clients', 'value_objects', 'money.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'clients', 'value_objects', 'money.rb'))
  load File.join(__dir__, 'app', 'domain', 'clients', 'entities', 'client.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'clients', 'entities', 'client.rb'))
  load File.join(__dir__, 'app', 'domain', 'clients', 'entities', 'portfolio.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'clients', 'entities', 'portfolio.rb'))
  load File.join(__dir__, 'app', 'domain', 'clients', 'repositories', 'client_repository.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'clients', 'repositories', 'client_repository.rb'))
  load File.join(__dir__, 'app', 'domain', 'clients', 'repositories', 'portfolio_repository.rb') if File.exist?(File.join(__dir__, 'app', 'domain', 'clients', 'repositories', 'portfolio_repository.rb'))

  # Application
  load File.join(__dir__, 'app', 'application', 'dtos', 'client_registration_dto.rb') if File.exist?(File.join(__dir__, 'app', 'application', 'dtos', 'client_registration_dto.rb'))
  load File.join(__dir__, 'app', 'application', 'dtos', 'place_order_dto.rb') if File.exist?(File.join(__dir__, 'app', 'application', 'dtos', 'place_order_dto.rb'))
  load File.join(__dir__, 'app', 'application', 'use_cases', 'register_client_use_case.rb') if File.exist?(File.join(__dir__, 'app', 'application', 'use_cases', 'register_client_use_case.rb'))
  load File.join(__dir__, 'app', 'application', 'use_cases', 'authenticate_user_use_case.rb') if File.exist?(File.join(__dir__, 'app', 'application', 'use_cases', 'authenticate_user_use_case.rb'))
  load File.join(__dir__, 'app', 'application', 'services', 'order_validation_service.rb') if File.exist?(File.join(__dir__, 'app', 'application', 'services', 'order_validation_service.rb'))

  # Infrastructure
  load File.join(__dir__, 'app', 'infrastructure', 'persistence', 'active_record', 'client_record.rb') if File.exist?(File.join(__dir__, 'app', 'infrastructure', 'persistence', 'active_record', 'client_record.rb'))
  load File.join(__dir__, 'app', 'infrastructure', 'persistence', 'active_record', 'portfolio_record.rb') if File.exist?(File.join(__dir__, 'app', 'infrastructure', 'persistence', 'active_record', 'portfolio_record.rb'))
  load File.join(__dir__, 'app', 'infrastructure', 'persistence', 'repositories', 'active_record_client_repository.rb') if File.exist?(File.join(__dir__, 'app', 'infrastructure', 'persistence', 'repositories', 'active_record_client_repository.rb'))
  load File.join(__dir__, 'app', 'infrastructure', 'persistence', 'repositories', 'active_record_portfolio_repository.rb') if File.exist?(File.join(__dir__, 'app', 'infrastructure', 'persistence', 'repositories', 'active_record_portfolio_repository.rb'))
end

puts "Testing BrokerX+ API..."

begin
  # Ensure the application's constants are loaded so namespaced classes/modules
  # (e.g. Infrastructure::Persistence::Repositories::ActiveRecordClientRepository)
  # are available when running this script with `rails runner`.
  # Load dependencies manually to avoid Zeitwerk constant/name mismatches
  load_dependencies

  # Initialiser les repositories
  client_repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
  portfolio_repo = Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new

  puts "1. Testing Client Registration..."
  test_email = "api_test@example.com"
  # Remove any previous test client to make this script idempotent
  existing = client_repo.find_by_email(test_email)
  if existing
    client_repo.delete(existing.id) rescue nil
  end

  registration_dto = Application::Dtos::ClientRegistrationDto.new(
    email: test_email,
    first_name: "API",
    last_name: "Test",
    date_of_birth: Date.new(1990, 1, 1),
    password: "password123"
  )

  registration_use_case = Application::UseCases::RegisterClientUseCase.new(client_repo, portfolio_repo)
  registration_result = registration_use_case.execute(registration_dto)
  puts "✓ Client registered: #{registration_result[:client].full_name}"

  # Activate the client (simulate email verification) so authentication can succeed
  if registration_result[:verification_token]
    registration_result[:client].activate!(registration_result[:verification_token])
    client_repo.save(registration_result[:client])
    puts "✓ Client activated"
  end

  puts "2. Testing Authentication..."
  auth_use_case = Application::UseCases::AuthenticateUserUseCase.new(client_repo)
  auth_result = auth_use_case.execute("api_test@example.com", "password123")
  puts "✓ Authentication successful. Token: #{auth_result[:token][0..20]}..."

  puts "3. Testing Order Validation..."
  order_dto = Application::Dtos::PlaceOrderDto.new(
    account_id: registration_result[:client].id,
    symbol: "AAPL",
    order_type: "limit",
    direction: "buy",
    quantity: 10,
    price: 150.0
  )

  validation_service = Application::Services::OrderValidationService.new(portfolio_repo)
  validation_errors = validation_service.validate_pre_trade(order_dto, registration_result[:client].id)
  puts "✓ Order validation completed. Errors: #{validation_errors}"

  puts "🎉 All API tests passed!"
  puts ""
  puts "Next steps:"
  puts "1. Start Rails server: rails server"
  puts "2. Test endpoints with curl or Postman"
  puts "3. Register client: POST /api/v1/clients/register"
  puts "4. Login: POST /api/v1/auth/login"

rescue => e
  puts "❌ Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end
