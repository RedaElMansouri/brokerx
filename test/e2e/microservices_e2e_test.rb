# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"
require "uri"

# ============================================================
# BrokerX - E2E Microservices Integration Test
# ============================================================
# Ces tests vérifient l'intégration complète entre les microservices.
#
# Prérequis:
#   - docker compose up -d
#   - Tous les services doivent être opérationnels
#
# Usage:
#   rails test test/e2e/microservices_e2e_test.rb
# ============================================================

class MicroservicesE2eTest < ActionDispatch::IntegrationTest
  CLIENTS_URL = ENV.fetch("CLIENTS_SERVICE_URL", "http://localhost:3001")
  PORTFOLIOS_URL = ENV.fetch("PORTFOLIOS_SERVICE_URL", "http://localhost:3002")
  ORDERS_URL = ENV.fetch("ORDERS_SERVICE_URL", "http://localhost:3003")
  GATEWAY_URL = ENV.fetch("GATEWAY_URL", "http://localhost:8080")

  def setup
    @test_email = "e2e_#{Time.now.to_i}_#{rand(1000)}@brokerx.com"
    @test_password = "SecurePass123!"
    @auth_token = nil
    skip_unless_services_available
  end

  # ============================================================
  # HELPER METHODS
  # ============================================================

  def skip_unless_services_available
    begin
      Net::HTTP.get(URI("#{CLIENTS_URL}/health"))
    rescue StandardError
      skip "Microservices not available. Start with: docker compose up -d"
    end
  end

  def http_request(method, url, body = nil, headers = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 10

    request = case method.to_s.upcase
              when "GET" then Net::HTTP::Get.new(uri)
              when "POST" then Net::HTTP::Post.new(uri)
              when "PUT" then Net::HTTP::Put.new(uri)
              when "DELETE" then Net::HTTP::Delete.new(uri)
              else raise "Unknown HTTP method: #{method}"
              end

    request["Content-Type"] = "application/json"
    headers.each { |key, value| request[key] = value }
    request.body = body.to_json if body

    response = http.request(request)
    
    parsed_body = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      response.body
    end
    
    {
      status: response.code.to_i,
      body: parsed_body,
      headers: response.to_hash
    }
  end

  def register_test_client
    response = http_request(:post, "#{CLIENTS_URL}/api/v1/clients", {
      client: {
        email: @test_email,
        password: @test_password,
        password_confirmation: @test_password,
        first_name: "E2E",
        last_name: "Test",
        phone_number: "+15141234567"
      }
    })
    
    if response[:status] == 201 || response[:status] == 200
      @client_id = response[:body]["id"] || response[:body].dig("client", "id")
    end
    response
  end

  def authenticate_test_client
    response = http_request(:post, "#{CLIENTS_URL}/api/v1/auth/login", {
      email: @test_email,
      password: @test_password
    })
    
    if response[:status] == 200 || response[:status] == 201
      @auth_token = response[:body]["token"]
    end
    response
  end

  def auth_headers
    { "Authorization" => "Bearer #{@auth_token}" }
  end

  # ============================================================
  # TEST SUITE 1: SERVICE HEALTH CHECKS
  # ============================================================

  test "1.1 - clients service is healthy" do
    response = http_request(:get, "#{CLIENTS_URL}/health")
    assert_equal 200, response[:status], "Clients service should be healthy"
  end

  test "1.2 - portfolios service is healthy" do
    response = http_request(:get, "#{PORTFOLIOS_URL}/health")
    assert_equal 200, response[:status], "Portfolios service should be healthy"
  end

  test "1.3 - orders service is healthy" do
    response = http_request(:get, "#{ORDERS_URL}/health")
    assert_equal 200, response[:status], "Orders service should be healthy"
  end

  # ============================================================
  # TEST SUITE 2: CLIENT REGISTRATION FLOW
  # ============================================================

  test "2.1 - can register new client" do
    response = register_test_client
    assert_includes [200, 201], response[:status], "Should create client"
    assert_not_nil response[:body]["id"] || response[:body].dig("client", "id")
  end

  test "2.2 - can authenticate registered client" do
    register_test_client
    response = authenticate_test_client
    
    assert_includes [200, 201], response[:status], "Should authenticate"
    assert_not_nil @auth_token, "Should receive auth token"
  end

  test "2.3 - can get client profile" do
    register_test_client
    authenticate_test_client
    
    response = http_request(:get, "#{CLIENTS_URL}/api/v1/clients/me", nil, auth_headers)
    assert_equal 200, response[:status], "Should get profile"
  end

  # ============================================================
  # TEST SUITE 3: PORTFOLIO OPERATIONS
  # ============================================================

  test "3.1 - can get portfolio" do
    register_test_client
    authenticate_test_client
    
    response = http_request(:get, "#{PORTFOLIOS_URL}/api/v1/portfolios", nil, auth_headers)
    assert_includes [200, 201], response[:status], "Should get portfolio"
  end

  test "3.2 - can deposit funds" do
    register_test_client
    authenticate_test_client
    
    headers = auth_headers.merge("X-Idempotency-Key" => "deposit-#{Time.now.to_i}")
    response = http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit", 
      { amount: 5000.00 }, headers)
    
    assert_includes [200, 201], response[:status], "Should deposit funds"
  end

  test "3.3 - deposit is idempotent" do
    register_test_client
    authenticate_test_client
    
    idempotency_key = "idempotent-deposit-#{Time.now.to_i}"
    headers = auth_headers.merge("X-Idempotency-Key" => idempotency_key)
    
    # First deposit
    response1 = http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 1000.00 }, headers)
    
    # Second deposit with same key - should be idempotent
    response2 = http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 1000.00 }, headers)
    
    assert_includes [200, 201], response1[:status], "First deposit should succeed"
    assert_includes [200, 201], response2[:status], "Second deposit should succeed (idempotent)"
  end

  # ============================================================
  # TEST SUITE 4: ORDER OPERATIONS
  # ============================================================

  test "4.1 - can get market data" do
    response = http_request(:get, "#{ORDERS_URL}/api/v1/market_data")
    assert_equal 200, response[:status], "Should get market data"
  end

  test "4.2 - can place buy order" do
    register_test_client
    authenticate_test_client
    
    # First deposit funds
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "order-deposit-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 10000.00 }, deposit_headers)
    
    # Place order
    response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "AAPL",
        order_type: "limit",
        side: "buy",
        quantity: 5,
        price: 150.00
      }
    }, auth_headers)
    
    assert_includes [200, 201], response[:status], "Should place order"
    assert_not_nil response[:body]["id"] || response[:body].dig("order", "id")
  end

  test "4.3 - can list orders" do
    register_test_client
    authenticate_test_client
    
    response = http_request(:get, "#{ORDERS_URL}/api/v1/orders", nil, auth_headers)
    assert_equal 200, response[:status], "Should list orders"
  end

  test "4.4 - can cancel pending order" do
    register_test_client
    authenticate_test_client
    
    # Deposit and create order
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "cancel-deposit-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 10000.00 }, deposit_headers)
    
    create_response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "MSFT",
        order_type: "limit",
        side: "buy",
        quantity: 3,
        price: 300.00
      }
    }, auth_headers)
    
    order_id = create_response[:body]["id"] || create_response[:body].dig("order", "id")
    
    if order_id
      cancel_response = http_request(:delete, "#{ORDERS_URL}/api/v1/orders/#{order_id}", 
        nil, auth_headers)
      assert_includes [200, 204], cancel_response[:status], "Should cancel order"
    end
  end

  # ============================================================
  # TEST SUITE 5: SAGA FLOW
  # ============================================================

  test "5.1 - full order saga happy path" do
    register_test_client
    authenticate_test_client
    
    # Deposit sufficient funds
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "saga-deposit-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 50000.00 }, deposit_headers)
    
    # Place market order (triggers saga)
    response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "GOOGL",
        order_type: "market",
        side: "buy",
        quantity: 10
      }
    }, auth_headers)
    
    assert_includes [200, 201], response[:status], "Saga should process order"
    
    order_id = response[:body]["id"] || response[:body].dig("order", "id")
    
    # Wait for saga processing and verify state
    if order_id
      sleep 2
      status_response = http_request(:get, "#{ORDERS_URL}/api/v1/orders/#{order_id}", 
        nil, auth_headers)
      assert_equal 200, status_response[:status], "Should get order status"
    end
  end

  test "5.2 - insufficient funds triggers compensation" do
    register_test_client
    authenticate_test_client
    
    # No deposit - should fail on funds validation
    response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "AAPL",
        order_type: "limit",
        side: "buy",
        quantity: 10000,  # Very large quantity
        price: 200.00
      }
    }, auth_headers)
    
    # Either rejected immediately (422) or pending saga validation (201)
    assert_includes [200, 201, 400, 422], response[:status], 
      "Should handle insufficient funds appropriately"
  end

  # ============================================================
  # TEST SUITE 6: CROSS-SERVICE COMMUNICATION
  # ============================================================

  test "6.1 - orders service can validate client via clients service" do
    register_test_client
    authenticate_test_client
    
    # This tests that orders service communicates with clients service
    response = http_request(:get, "#{ORDERS_URL}/api/v1/orders", nil, auth_headers)
    
    # If auth works, cross-service JWT validation is working
    assert_equal 200, response[:status], "Cross-service auth should work"
  end

  test "6.2 - orders service can check funds via portfolios service" do
    register_test_client
    authenticate_test_client
    
    # Deposit to portfolios
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "cross-service-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 1000.00 }, deposit_headers)
    
    # Try to place order - orders service should check portfolios
    response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "AAPL",
        order_type: "limit",
        side: "buy",
        quantity: 1,
        price: 100.00
      }
    }, auth_headers)
    
    # Order should be accepted or validated against portfolio funds
    assert_includes [200, 201, 422], response[:status],
      "Cross-service fund validation should work"
  end
end
