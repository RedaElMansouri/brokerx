# frozen_string_literal: true

# HTTP Client for Portfolios Service
# Used by Orders Service for TradingSaga (reserve/release funds)
class PortfoliosClient
  class ServiceUnavailableError < StandardError; end
  class InsufficientFundsError < StandardError; end

  def initialize
    @base_url = ENV.fetch('PORTFOLIOS_SERVICE_URL', 'http://portfolios-service:3000')
    @internal_token = ENV.fetch('INTERNAL_SERVICE_TOKEN', 'internal_service_secret')
    @timeout = 5
  end

  # Reserve funds for an order
  def reserve_funds(client_id:, amount:, order_id:)
    response = make_request(:post, '/internal/reserve', {
      client_id: client_id,
      amount: amount,
      order_id: order_id
    })

    unless response[:success]
      if response[:error]&.include?('Insufficient funds')
        raise InsufficientFundsError, "Insufficient funds for order #{order_id}"
      end
      raise ServiceUnavailableError, response[:error] || 'Reserve failed'
    end

    response
  end

  # Release reserved funds (compensation on order failure/cancellation)
  def release_funds(client_id:, amount:, order_id:)
    response = make_request(:post, '/internal/release', {
      client_id: client_id,
      amount: amount,
      order_id: order_id
    })

    unless response[:success]
      Rails.logger.error("[PortfoliosClient] Failed to release funds: #{response[:error]}")
    end

    response
  end

  # Debit funds after order execution
  def debit_funds(client_id:, amount:, order_id:)
    make_request(:post, '/internal/debit', {
      client_id: client_id,
      amount: amount,
      order_id: order_id
    })
  end

  # Check available balance
  def check_balance(client_id:)
    make_request(:get, "/internal/balance/#{client_id}")
  end

  # Health check
  def health
    make_request(:get, '/health')
  rescue StandardError
    { success: false, status: 'unavailable' }
  end

  private

  def make_request(method, path, body = nil)
    uri = URI.parse("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = @timeout
    http.open_timeout = @timeout

    request = case method
              when :get
                Net::HTTP::Get.new(uri.request_uri)
              when :post
                req = Net::HTTP::Post.new(uri.request_uri)
                req.body = body.to_json if body
                req
              end

    request['Content-Type'] = 'application/json'
    request['X-Internal-Token'] = @internal_token

    response = http.request(request)
    parse_response(response)
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[PortfoliosClient] Connection error: #{e.message}")
    raise ServiceUnavailableError, "Portfolios service unavailable: #{e.message}"
  end

  def parse_response(response)
    body = JSON.parse(response.body, symbolize_names: true)
    
    case response.code.to_i
    when 200..299
      body.merge(success: true)
    when 400..499
      body.merge(success: false)
    when 500..599
      { success: false, error: "Server error: #{response.code}" }
    else
      { success: false, error: "Unknown response: #{response.code}" }
    end
  rescue JSON::ParserError
    { success: false, error: 'Invalid JSON response' }
  end
end
