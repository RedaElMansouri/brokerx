require 'test_helper'

class E2EDepositFundsTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'deposit@example.com',
      first_name: 'Depo',
      last_name: 'Sit',
      date_of_birth: '1990-01-01',
      status: 'active',
      password: 'secret'
    )

    @portfolio = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id,
      currency: 'USD',
      available_balance: 0.0,
      reserved_balance: 0.0
    )

    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'deposit of 1000 increases balance and writes journal entry' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json', 'Idempotency-Key' => SecureRandom.uuid }
    payload = { amount: 1000.0, currency: 'USD' }

    assert_difference -> { Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.count }, +1 do
      post '/api/v1/deposits', params: payload.to_json, headers: headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal true, body['success']
    assert_equal 'settled', body['status']
    assert body['transaction_id']
    assert_equal 1000.0, body['balance_after']

    @portfolio.reload
    assert_equal BigDecimal('1000.0'), @portfolio.available_balance
  end

  test 'idempotent deposit does not double credit' do
    key = SecureRandom.uuid
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json', 'Idempotency-Key' => key }
    payload = { amount: 250.0, currency: 'USD' }

    post '/api/v1/deposits', params: payload.to_json, headers: headers
    assert_response :created

    assert_no_difference -> { Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.count } do
      post '/api/v1/deposits', params: payload.to_json, headers: headers
    end
    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal true, body['success']
    assert_equal 'settled', body['status']

  @portfolio.reload
  assert_equal BigDecimal('250.0'), @portfolio.available_balance
  end

  test 'unauthorized without token' do
    post '/api/v1/deposits', params: { amount: 100.0 }.to_json, headers: { 'Content-Type' => 'application/json' }
    assert_response :unauthorized
  end

  test 'validation error on too small amount' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json', 'Idempotency-Key' => SecureRandom.uuid }
    post '/api/v1/deposits', params: { amount: 0.0 }.to_json, headers: headers
    assert_response :unprocessable_content
  end
end
