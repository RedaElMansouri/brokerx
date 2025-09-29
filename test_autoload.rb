# test_autoload.rb
puts "Testing autoload..."

# Test des classes principales
classes_to_test = [
  'Domain::Shared::ValueObject',
  'Domain::Shared::Entity',
  'Domain::Clients::ValueObjects::Email',
  'Domain::Clients::Entities::Client',
  'Application::Dtos::ClientRegistrationDto',
  'Application::UseCases::RegisterClientUseCase',
  'ClientRecord',
  'PortfolioRecord',
  'Infrastructure::Persistence::Repositories::ActiveRecordClientRepository'
]

classes_to_test.each do |class_name|
  begin
    klass = class_name.constantize
    puts "✓ #{class_name}"
  rescue => e
    puts "✗ #{class_name}: #{e.message}"
  end
end

puts "\nTesting domain object creation..."
begin
  email = Domain::Clients::ValueObjects::Email.new("test@example.com")
  puts "✓ Email created: #{email.value}"

  client = Domain::Clients::Entities::Client.new(
    email: "test@example.com",
    first_name: "Test",
    last_name: "User",
    date_of_birth: Date.new(1990, 1, 1)
  )
  puts "✓ Client created: #{client.full_name}"
rescue => e
  puts "✗ Domain creation failed: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end
