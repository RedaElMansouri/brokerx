# frozen_string_literal: true

# Seeds for Clients Service development

puts 'Creating test clients...'

# Create a verified test client
client = Client.create!(
  email: 'test@brokerx.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Test User',
  email_verified: true,
  email_verified_at: Time.current,
  mfa_enabled: true
)

puts "Created client: #{client.email}"

# Create an unverified client
unverified = Client.create!(
  email: 'unverified@brokerx.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Unverified User'
)

puts "Created unverified client: #{unverified.email}"

puts 'Seeds completed!'
