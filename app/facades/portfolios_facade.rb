# frozen_string_literal: true

# Facade for Portfolios Service (UC-03)
# Strangler Fig Pattern - delegates to portfolios-service microservice
class PortfoliosFacade < BaseFacade
  # UC-03: Deposit funds (idempotent)
  def deposit(jwt_token:, amount:, currency: 'USD', idempotency_key:)
    make_request(:post, '/api/v1/deposits', {
      amount: amount,
      currency: currency
    }, {
      'Authorization' => "Bearer #{jwt_token}",
      'Idempotency-Key' => idempotency_key
    })
  end

  # Get portfolio balance
  def get_portfolio(jwt_token:)
    make_request(:get, '/api/v1/portfolio', {}, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # Get deposit history
  def get_deposits(jwt_token:)
    make_request(:get, '/api/v1/deposits', {}, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # ============ INTERNAL APIs (called by Orders Service) ============

  # Reserve funds for an order
  def reserve_funds(client_id:, amount:, order_id:, internal_token:)
    make_request(:post, '/internal/reserve', {
      client_id: client_id,
      amount: amount,
      order_id: order_id
    }, {
      'X-Internal-Token' => internal_token
    })
  end

  # Release reserved funds (compensation on order failure)
  def release_funds(client_id:, amount:, order_id:, internal_token:)
    make_request(:post, '/internal/release', {
      client_id: client_id,
      amount: amount,
      order_id: order_id
    }, {
      'X-Internal-Token' => internal_token
    })
  end

  # Debit funds after order execution
  def debit_funds(client_id:, amount:, order_id:, internal_token:)
    make_request(:post, '/internal/debit', {
      client_id: client_id,
      amount: amount,
      order_id: order_id
    }, {
      'X-Internal-Token' => internal_token
    })
  end

  # Check available balance
  def check_balance(client_id:, internal_token:)
    make_request(:get, "/internal/balance/#{client_id}", {}, {
      'X-Internal-Token' => internal_token
    })
  end

  # Health check
  def health
    make_request(:get, '/health')
  end

  protected

  def service_url
    ENV.fetch('PORTFOLIOS_SERVICE_URL', 'http://localhost:3002')
  end
end
