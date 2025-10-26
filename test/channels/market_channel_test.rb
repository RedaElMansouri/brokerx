require 'test_helper'

class MarketChannelTest < ActionCable::Channel::TestCase
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'ws@example.com',
      first_name: 'WS',
      last_name: 'User',
      date_of_birth: '1990-01-01',
      status: 'active',
      password: 'secret'
    )
    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'subscribes to AAPL and receives initial data' do
    stub_connection current_client_id: @client.id
    subscribe(symbols: ['AAPL'])

    assert subscription.confirmed?
  assert_has_stream "market:AAPL"

    # Initial transmissions include one orderbook snapshot and one quote
    types = transmissions.map { |t| t[:type] }
    assert_includes types, 'orderbook'
    assert_includes types, 'quote'

    # Each payload should reference the symbol
    transmissions.each do |t|
      assert_equal 'AAPL', t[:symbol]
    end
  end

  test 'rejects when no symbols provided' do
    stub_connection current_client_id: @client.id
    subscribe
    refute subscription.confirmed?
  end

  test 'rejects unauthorized connection' do
    stub_connection current_client_id: nil
    subscribe(symbols: ['AAPL'])
    refute subscription.confirmed?
  end
end
