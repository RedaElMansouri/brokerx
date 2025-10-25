require 'test_helper'

class E2ECreateMissingParamsTest < ActionDispatch::IntegrationTest
  def setup
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'mp@example.com', first_name: 'Missing', last_name: 'Params', date_of_birth: '1990-01-01', status: 'active', password: 'secret'
    )
    Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id, currency: 'USD', available_balance: 10_000.0, reserved_balance: 0.0
    )
    repo = Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
    @token = Application::UseCases::AuthenticateUserUseCase.new(repo).send(:generate_jwt_token, @client.id)
  end

  test 'create without order param returns bad_request' do
    headers = { 'Authorization' => "Bearer #{@token}", 'Content-Type' => 'application/json',
                'Accept' => 'application/json' }
    post '/api/v1/orders', params: {}.to_json, headers: headers
    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_equal 'bad_request', body['code']
    assert_includes body['message'], 'param is missing'
  end
end
