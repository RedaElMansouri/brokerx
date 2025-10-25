require 'test_helper'

class E2EOrdersFlowTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'e2e@example.com',
      first_name: 'E2E',
      last_name: 'Test',
      date_of_birth: '1990-01-01',
      status: 'active',
      password: 'secret'
    )

    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id,
      currency: 'USD',
      available_balance: 10_000.0,
      reserved_balance: 0.0
    )

    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'place a simple market buy order' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = {
      order: {
        symbol: 'AAPL',
        order_type: 'market',
        direction: 'buy',
        quantity: 5
      }
    }

    post '/api/v1/orders', params: payload.to_json, headers: headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body['success']
    assert body['order_id']
  end
end
