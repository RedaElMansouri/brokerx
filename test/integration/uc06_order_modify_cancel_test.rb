require 'test_helper'

class UC06OrderModifyCancelTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'order_uc06@example.com',
      first_name: 'Order',
      last_name: 'User',
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

  def place_buy_order(symbol: 'AAPL', quantity: 10, price: 10.0)
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = {
      order: {
        symbol: symbol,
        order_type: 'limit',
        direction: 'buy',
        quantity: quantity,
        price: price,
        time_in_force: 'DAY'
      }
    }
    post '/api/v1/orders', params: payload.to_json, headers: headers
    assert_response :success
    JSON.parse(response.body)
  end

  test 'replace reduces reserved funds and bumps lock_version' do
    create_resp = place_buy_order(quantity: 10, price: 10.0)
    order_id = create_resp['order_id']
    lock_version = create_resp['lock_version']

    # Replace: lower price from 10.0 to 8.0 (reserved should go from 100 to 80)
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = { order: { price: 8.0, client_version: lock_version } }
    post "/api/v1/orders/#{order_id}/replace", params: payload.to_json, headers: headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body['success']
  assert_equal 8.0, body['price'].to_f
    assert_equal 80.0, body['reserved_amount'].to_f
    assert_equal lock_version + 1, body['lock_version']

    # Verify portfolio balances reflect release of 20
    @portfolio.reload
    assert_equal BigDecimal('9920.0'), @portfolio.available_balance
    assert_equal BigDecimal('80.0'), @portfolio.reserved_balance
  end

  test 'replace with stale client_version returns conflict' do
    create_resp = place_buy_order(quantity: 5, price: 20.0)
    order_id = create_resp['order_id']
    stale_version = create_resp['lock_version'] - 1 # invalid on purpose

    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = { order: { price: 21.0, client_version: stale_version } }
    post "/api/v1/orders/#{order_id}/replace", params: payload.to_json, headers: headers
    assert_response :conflict

    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_equal 'version_conflict', body['code']
  end

  test 'cancel releases funds and sets status cancelled' do
    create_resp = place_buy_order(quantity: 2, price: 50.0) # reserve 100
    order_id = create_resp['order_id']
    lock_version = create_resp['lock_version']

    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = { client_version: lock_version }
    post "/api/v1/orders/#{order_id}/cancel", params: payload.to_json, headers: headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body['success']
    assert_equal 'cancelled', body['status']

    # Verify funds released
    @portfolio.reload
    assert_equal BigDecimal('10000.0'), @portfolio.available_balance
    assert_equal BigDecimal('0.0'), @portfolio.reserved_balance
  end

  test 'replace increases reserved funds when price increases' do
    # initial: 10 * 10 = 100 reserved
    create_resp = place_buy_order(quantity: 10, price: 10.0)
    order_id = create_resp['order_id']
    lock_version = create_resp['lock_version']

    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }
    payload = { order: { price: 15.0, client_version: lock_version } } # new cost = 150
    post "/api/v1/orders/#{order_id}/replace", params: payload.to_json, headers: headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body['success']
    assert_equal 150.0, body['reserved_amount'].to_f

    @portfolio.reload
    assert_equal BigDecimal('9850.0'), @portfolio.available_balance
    assert_equal BigDecimal('150.0'), @portfolio.reserved_balance
  end

  test 'replace validation errors return 422' do
    create_resp = place_buy_order(quantity: 1, price: 10.0)
    order_id = create_resp['order_id']
    lock_version = create_resp['lock_version']

    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json' }

    # quantity must be positive
    post "/api/v1/orders/#{order_id}/replace", params: { order: { quantity: 0, client_version: lock_version } }.to_json, headers: headers
    assert_response :unprocessable_content
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_includes Array(body['errors']), 'Quantity must be positive'
  end
end
