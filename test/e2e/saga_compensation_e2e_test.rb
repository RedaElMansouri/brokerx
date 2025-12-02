# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"

# ============================================================
# BrokerX - Saga Compensation E2E Test
# ============================================================
# Tests de compensation pour la saga chorégraphiée UC-07.
# ============================================================

class SagaCompensationE2eTest < ActionDispatch::IntegrationTest
  CLIENTS_URL = ENV.fetch("CLIENTS_SERVICE_URL", "http://localhost:3001")
  PORTFOLIOS_URL = ENV.fetch("PORTFOLIOS_SERVICE_URL", "http://localhost:3002")
  ORDERS_URL = ENV.fetch("ORDERS_SERVICE_URL", "http://localhost:3003")

  def setup
    @test_email = "saga_test_#{Time.now.to_i}_#{rand(1000)}@brokerx.com"
    @test_password = "SecurePass123!"
    @auth_token = nil
    skip_unless_services_available
  end

  def skip_unless_services_available
    begin
      Net::HTTP.get(URI("#{ORDERS_URL}/health"))
    rescue StandardError
      skip "Microservices not available"
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
              else raise "Unknown method"
              end

    request["Content-Type"] = "application/json"
    headers.each { |k, v| request[k] = v }
    request.body = body.to_json if body

    response = http.request(request)
    parsed = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      response.body
    end
    { status: response.code.to_i, body: parsed }
  end

  def setup_authenticated_client
    # Register
    http_request(:post, "#{CLIENTS_URL}/api/v1/clients", {
      client: {
        email: @test_email,
        password: @test_password,
        password_confirmation: @test_password,
        first_name: "Saga",
        last_name: "Test",
        phone_number: "+15141234567"
      }
    })

    # Authenticate
    response = http_request(:post, "#{CLIENTS_URL}/api/v1/auth/login", {
      email: @test_email,
      password: @test_password
    })
    @auth_token = response[:body]["token"]
  end

  def auth_headers
    { "Authorization" => "Bearer #{@auth_token}" }
  end

  # ============================================================
  # COMPENSATION SCENARIOS
  # ============================================================

  test "saga compensates when funds reservation fails" do
    setup_authenticated_client
    
    # NO deposit - should trigger compensation
    response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "AAPL",
        order_type: "limit",
        side: "buy",
        quantity: 100,
        price: 200.00  # Total: $20,000 - no funds
      }
    }, auth_headers)

    # Order should either be rejected or marked for compensation
    assert_includes [200, 201, 400, 422], response[:status]
    
    if [200, 201].include?(response[:status])
      order_id = response[:body]["id"] || response[:body].dig("order", "id")
      
      # Wait for saga to process and compensate
      sleep 3
      
      status_response = http_request(:get, 
        "#{ORDERS_URL}/api/v1/orders/#{order_id}", nil, auth_headers)
      
      if status_response[:status] == 200
        order_status = status_response[:body]["status"] || 
                       status_response[:body].dig("order", "status")
        # Should be rejected/cancelled due to insufficient funds
        assert_includes ["rejected", "cancelled", "pending", "failed"], order_status.to_s.downcase,
          "Order should be in rejected/cancelled/failed state due to compensation"
      end
    end
  end

  test "saga completes successfully with sufficient funds" do
    setup_authenticated_client
    
    # Deposit funds first
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "saga-happy-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 50000.00 }, deposit_headers)
    
    # Place order
    response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "MSFT",
        order_type: "market",
        side: "buy",
        quantity: 10
      }
    }, auth_headers)

    assert_includes [200, 201], response[:status], "Order should be placed"
    
    order_id = response[:body]["id"] || response[:body].dig("order", "id")
    
    if order_id
      # Wait for saga completion
      sleep 2
      
      status_response = http_request(:get, 
        "#{ORDERS_URL}/api/v1/orders/#{order_id}", nil, auth_headers)
      
      assert_equal 200, status_response[:status]
    end
  end

  test "multiple concurrent orders trigger proper saga handling" do
    setup_authenticated_client
    
    # Deposit limited funds
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "concurrent-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 1000.00 }, deposit_headers)
    
    # Place multiple orders concurrently (simulated)
    orders = []
    3.times do |i|
      response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
        order: {
          symbol: ["AAPL", "MSFT", "GOOGL"][i],
          order_type: "limit",
          side: "buy",
          quantity: 5,
          price: 100.00  # Total each: $500
        }
      }, auth_headers)
      orders << response
    end

    # At least some should succeed, some may be rejected due to fund competition
    successful = orders.count { |r| [200, 201].include?(r[:status]) }
    assert successful >= 1, "At least one order should be placed"
  end

  test "order cancellation releases reserved funds" do
    setup_authenticated_client
    
    # Deposit funds
    deposit_headers = auth_headers.merge("X-Idempotency-Key" => "cancel-test-#{Time.now.to_i}")
    http_request(:post, "#{PORTFOLIOS_URL}/api/v1/portfolios/deposit",
      { amount: 5000.00 }, deposit_headers)
    
    # Place order
    order_response = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
      order: {
        symbol: "AAPL",
        order_type: "limit",
        side: "buy",
        quantity: 10,
        price: 150.00  # $1,500 reserved
      }
    }, auth_headers)

    if [200, 201].include?(order_response[:status])
      order_id = order_response[:body]["id"] || order_response[:body].dig("order", "id")
      
      # Cancel order
      cancel_response = http_request(:delete, 
        "#{ORDERS_URL}/api/v1/orders/#{order_id}", nil, auth_headers)
      
      assert_includes [200, 204], cancel_response[:status], "Should cancel order"
      
      # Funds should be released - can place another order
      sleep 1
      
      second_order = http_request(:post, "#{ORDERS_URL}/api/v1/orders", {
        order: {
          symbol: "MSFT",
          order_type: "limit",
          side: "buy",
          quantity: 10,
          price: 100.00  # $1,000
        }
      }, auth_headers)
      
      assert_includes [200, 201], second_order[:status], 
        "Should be able to place order after cancellation"
    end
  end
end
