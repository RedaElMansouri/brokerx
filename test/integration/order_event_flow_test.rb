require 'test_helper'
require 'jwt'

class OrderEventFlowTest < ActionDispatch::IntegrationTest
  def setup
    @secret = Rails.application.secret_key_base
  end

  test 'successful order creation writes outbox event and returns correlation id header' do
    client_id = create_client!(email: 'flow1@example.test')
    create_portfolio!(client_id: client_id, available: 10_000, reserved: 0)
    token = jwt_for(client_id)

    payload = {
      order: {
        symbol: 'AAPL', order_type: 'limit', direction: 'buy', quantity: 10, price: 100.0, time_in_force: 'DAY'
      }
    }
    corr = SecureRandom.uuid
    post '/api/v1/orders', params: payload.to_json, headers: auth_headers(token, corr)
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['order_id']
    assert_equal corr, json['correlation_id']
    assert_equal corr, @response.get_header('X-Correlation-Id')
    evt = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.find_by(entity_id: json['order_id'], event_type: 'order.created')
    assert evt, 'expected order.created outbox event'
    assert_equal 'pending', evt.status
  end

  test 'insufficient funds prevents outbox event creation' do
    client_id = create_client!(email: 'flow2@example.test')
    create_portfolio!(client_id: client_id, available: 50, reserved: 0)
    token = jwt_for(client_id)
    payload = { order: { symbol: 'MSFT', order_type: 'limit', direction: 'buy', quantity: 10, price: 100.0, time_in_force: 'DAY' } }
    post '/api/v1/orders', params: payload.to_json, headers: auth_headers(token)
    assert_response :unprocessable_entity
    json = JSON.parse(@response.body)
    assert_equal false, json['success']
    evt = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.where(event_type: 'order.created').last
    refute evt && evt.payload['account_id'] == client_id, 'no outbox event should be written for rejected order'
  end

  test 'manual processing of order.created produces execution.report' do
    client_id = create_client!(email: 'flow3@example.test')
    create_portfolio!(client_id: client_id, available: 5000, reserved: 0)
    token = jwt_for(client_id)
    payload = { order: { symbol: 'GOOG', order_type: 'limit', direction: 'buy', quantity: 5, price: 10.0, time_in_force: 'DAY' } }
    post '/api/v1/orders', params: payload.to_json, headers: auth_headers(token)
    assert_response :success
    order_id = JSON.parse(@response.body)['order_id']
    out_evt = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.find_by(entity_id: order_id, event_type: 'order.created')
    assert out_evt
    # Simulate dispatcher call
    Application::Services::MatchingEngine.instance.test_process(order_id: order_id, symbol: 'GOOG', direction: 'buy', order_type: 'limit', quantity: 5, price: 10.0)
    exec_evt = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.where(event_type: 'execution.report', entity_id: order_id).last
    assert exec_evt, 'expected execution.report after processing'
    assert_includes %w[working filled], exec_evt.payload['status']
  end

  private

  def jwt_for(client_id)
    payload = { client_id: client_id, iss: 'brokerx', aud: 'brokerx.web', exp: (Time.now + 3600).to_i }
    JWT.encode(payload, @secret, 'HS256')
  end

  def auth_headers(token, correlation_id = nil)
    h = { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
    h['X-Correlation-Id'] = correlation_id if correlation_id
    h
  end

  def create_client!(email:)
    Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: email,
      phone: '1234567890',
      first_name: 'Test',
      last_name: 'User',
      date_of_birth: Date.new(1990,1,1),
      status: 'verified'
    ).id
  end

  def create_portfolio!(client_id:, available:, reserved: 0, currency: 'USD')
    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: client_id,
      currency: currency,
      available_balance: available,
      reserved_balance: reserved
    )
  end
end
