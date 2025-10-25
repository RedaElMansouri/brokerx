require 'test_helper'

class E2EShowOrderForbiddenTest < ActionDispatch::IntegrationTest
  def setup
    @client_a = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'a@example.com', first_name: 'A', last_name: 'User', date_of_birth: '1990-01-01', status: 'active', password: 'secret'
    )
    @client_b = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'b@example.com', first_name: 'B', last_name: 'User', date_of_birth: '1990-01-01', status: 'active', password: 'secret'
    )

    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client_a.id, currency: 'USD', available_balance: 10_000.0, reserved_balance: 0.0
    )
    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client_b.id, currency: 'USD', available_balance: 10_000.0, reserved_balance: 0.0
    )

    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token_a = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client_a.id)
    @token_b = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client_b.id)

    # Create an order for client A
    headers_a = { 'Authorization' => "Bearer #{@token_a}", 'Content-Type' => 'application/json' }
    payload = { order: { symbol: 'AAPL', order_type: 'market', direction: 'buy', quantity: 1 } }
    post '/api/v1/orders', params: payload.to_json, headers: headers_a
    body = JSON.parse(response.body)
    @order_id = body['order_id']
  end

  test 'client B cannot view client A order' do
    headers_b = { 'Authorization' => "Bearer #{@token_b}" }
    get "/api/v1/orders/#{@order_id}", headers: headers_b
    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_equal 'forbidden', body['code']
  end
end
