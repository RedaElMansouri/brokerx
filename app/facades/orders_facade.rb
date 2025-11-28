# frozen_string_literal: true

# Facade for Orders Service (UC-04 to UC-08)
# Strangler Fig Pattern - delegates to orders-service microservice
class OrdersFacade < BaseFacade
  # UC-04: Get market data for a symbol
  def get_market_data(jwt_token:, symbol:)
    make_request(:get, "/api/v1/market_data/#{symbol}", {}, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # UC-05: Place a new order
  def place_order(jwt_token:, symbol:, direction:, order_type:, quantity:, price: nil, time_in_force: 'DAY', idempotency_key:)
    make_request(:post, '/api/v1/orders', {
      symbol: symbol,
      direction: direction,
      order_type: order_type,
      quantity: quantity,
      price: price,
      time_in_force: time_in_force
    }, {
      'Authorization' => "Bearer #{jwt_token}",
      'Idempotency-Key' => idempotency_key
    })
  end

  # UC-06: Modify an order (replace)
  def modify_order(jwt_token:, order_id:, price: nil, quantity: nil, client_version:)
    make_request(:post, "/api/v1/orders/#{order_id}/replace", {
      order: {
        price: price,
        quantity: quantity,
        client_version: client_version
      }
    }, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # UC-06: Cancel an order
  def cancel_order(jwt_token:, order_id:)
    make_request(:post, "/api/v1/orders/#{order_id}/cancel", {}, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # Get order details
  def get_order(jwt_token:, order_id:)
    make_request(:get, "/api/v1/orders/#{order_id}", {}, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # Get all orders for client
  def get_orders(jwt_token:, limit: 50)
    make_request(:get, '/api/v1/orders', { limit: limit }, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # UC-08: Get execution reports
  def get_executions(jwt_token:, limit: 50)
    make_request(:get, '/api/v1/executions', { limit: limit }, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # Get trades history
  def get_trades(jwt_token:, limit: 50)
    make_request(:get, '/api/v1/trades', { limit: limit }, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # Health check
  def health
    make_request(:get, '/health')
  end

  protected

  def service_url
    ENV.fetch('ORDERS_SERVICE_URL', 'http://localhost:3003')
  end
end
