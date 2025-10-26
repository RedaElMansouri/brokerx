require 'test_helper'

class UC05OrderIdempotencyTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'order_idempo@example.com',
      first_name: 'Order',
      last_name: 'Idempo',
      date_of_birth: '1990-01-01',
      status: 'active',
      password: 'secret'
    )

    @portfolio = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id,
      currency: 'USD',
      available_balance: 10000.0,
      reserved_balance: 0.0
    )

    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'placing same client_order_id is idempotent and reserves once' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    client_order_id = SecureRandom.uuid

    payload = {
      order: {
        symbol: 'AAPL', order_type: 'limit', direction: 'buy', quantity: 5, price: 10.0,
        client_order_id: client_order_id
      }
    }

    post '/api/v1/orders', params: payload.to_json, headers: headers
    assert_response :success
    body1 = JSON.parse(response.body)
    id1 = body1['order_id']
    lv1 = body1['lock_version']

    # Replay with same client_order_id
    post '/api/v1/orders', params: payload.to_json, headers: headers
    assert_response :success
    body2 = JSON.parse(response.body)
    id2 = body2['order_id']
    lv2 = body2['lock_version']

    assert_equal id1, id2, 'Idempotent replay must reference same order'
    assert_equal lv1, lv2, 'Lock version should not change on idempotent replay'

    # Funds reserved only once: 5 * 10 = 50
    @portfolio.reload
    assert_equal BigDecimal('9950.0'), @portfolio.available_balance
    assert_equal BigDecimal('50.0'), @portfolio.reserved_balance
  end
end
