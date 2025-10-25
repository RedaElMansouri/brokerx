require 'test_helper'

class E2EInsufficientFundsTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'nofunds@example.com',
      first_name: 'No',
      last_name: 'Funds',
      date_of_birth: '1990-01-01',
      status: 'active',
      password: 'secret'
    )

    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id,
      currency: 'USD',
      available_balance: 1_000.0,
      reserved_balance: 0.0
    )

    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'reject order when funds are insufficient' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = {
      order: {
        symbol: 'TSLA',
        order_type: 'market',
        direction: 'buy',
        quantity: 100 # default price ~100 => 10_000 cost > 1_000 balance
      }
    }

    post '/api/v1/orders', params: payload.to_json, headers: headers

    assert_response :unprocessable_content
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_includes body['errors'], 'Insufficient funds'
  end
end
