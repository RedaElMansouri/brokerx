require 'test_helper'

class E2EShowOrderNotFoundTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'nf@example.com', first_name: 'Not', last_name: 'Found', date_of_birth: '1990-01-01', status: 'active', password: 'secret'
    )
    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id, currency: 'USD', available_balance: 10_000.0, reserved_balance: 0.0
    )
    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'show returns 404 for non-existing order' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Accept' => 'application/json' }
    get '/api/v1/orders/999999', headers: headers
    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_equal 'not_found', body['code']
  end
end
