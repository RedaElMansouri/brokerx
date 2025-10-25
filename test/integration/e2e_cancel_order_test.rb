require 'test_helper'

class E2ECancelOrderTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'cancel@example.com',
      first_name: 'Cancel',
      last_name: 'Case',
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

  test 'cancel an existing order and release funds' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }

    # Place an order first
    payload = {
      order: {
        symbol: 'AAPL',
        order_type: 'limit',
        direction: 'buy',
        quantity: 5,
        price: 100
      }
    }

    post '/api/v1/orders', params: payload.to_json, headers: headers
    assert_response :success
    create_body = JSON.parse(response.body)
    order_id = create_body['order_id']
    assert order_id, 'order_id should be present in create response'

    # Cancel the order
    delete "/api/v1/orders/#{order_id}", headers: headers
    assert_response :success

    cancel_body = JSON.parse(response.body)
    assert_equal true, cancel_body['success']
    assert_equal 'Order cancelled', cancel_body['message']
  end
end
