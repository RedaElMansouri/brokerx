# frozen_string_literal: true

# UC-05: Place Order
# Validates and places a buy/sell order with pre-trade checks
class PlaceOrderUseCase
  VALID_SYMBOLS = %w[AAPL MSFT GOOGL AMZN META TSLA NVDA].freeze
  PRICE_BAND_MIN = 1.00
  PRICE_BAND_MAX = 10_000.00

  def execute(client_id:, symbol:, direction:, order_type:, quantity:, price:, time_in_force:, correlation_id: nil, idempotency_key: nil)
    # Validate inputs
    validation_result = validate_inputs(symbol, direction, order_type, quantity, price)
    return validation_result unless validation_result[:success]

    # Check funds for buy orders (simplified - would call portfolios-service in production)
    if direction == 'buy'
      estimated_cost = calculate_cost(order_type, quantity, price, symbol)
      funds_result = check_funds(client_id, estimated_cost)
      return funds_result unless funds_result[:success]
    end

    # Pre-trade checks
    pretrade_result = pretrade_checks(order_type, price, symbol)
    return pretrade_result unless pretrade_result[:success]

    # Create order in transaction
    order = nil
    ActiveRecord::Base.transaction do
      order = Order.create!(
        client_id: client_id,
        symbol: symbol.upcase,
        direction: direction,
        order_type: order_type,
        quantity: quantity,
        price: order_type == 'limit' ? price : nil,
        time_in_force: time_in_force,
        status: 'new',
        reserved_amount: direction == 'buy' ? calculate_cost(order_type, quantity, price, symbol) : 0,
        correlation_id: correlation_id,
        idempotency_key: idempotency_key
      )

      # Create outbox event for matching engine
      OutboxEvent.create!(
        aggregate_type: 'Order',
        aggregate_id: order.id,
        event_type: 'order.created',
        payload: {
          order_id: order.id,
          client_id: client_id,
          symbol: order.symbol,
          direction: direction,
          order_type: order_type,
          quantity: quantity,
          price: order.price,
          time_in_force: time_in_force,
          correlation_id: correlation_id,
          timestamp: Time.current.iso8601
        }
      )
    end

    # Enqueue to matching engine
    MatchingEngine.instance.enqueue_order(order)

    {
      success: true,
      order: order,
      correlation_id: correlation_id
    }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: e.message, code: 'validation_error' }
  rescue StandardError => e
    Rails.logger.error("PlaceOrderUseCase error: #{e.message}")
    { success: false, error: e.message, code: 'processing_error' }
  end

  private

  def validate_inputs(symbol, direction, order_type, quantity, price)
    errors = []

    # Symbol validation
    unless VALID_SYMBOLS.include?(symbol&.upcase)
      errors << "Invalid symbol. Valid symbols: #{VALID_SYMBOLS.join(', ')}"
    end

    # Direction validation
    unless %w[buy sell].include?(direction)
      errors << "Direction must be 'buy' or 'sell'"
    end

    # Order type validation
    unless %w[market limit].include?(order_type)
      errors << "Order type must be 'market' or 'limit'"
    end

    # Quantity validation
    if quantity.nil? || quantity <= 0
      errors << 'Quantity must be greater than 0'
    end

    # Price validation for limit orders
    if order_type == 'limit' && (price.nil? || price <= 0)
      errors << 'Price is required for limit orders and must be greater than 0'
    end

    if errors.any?
      { success: false, error: errors.join('. '), code: 'validation_error' }
    else
      { success: true }
    end
  end

  def pretrade_checks(order_type, price, _symbol)
    return { success: true } if order_type == 'market'

    # Price band check for limit orders
    if price < PRICE_BAND_MIN || price > PRICE_BAND_MAX
      return {
        success: false,
        error: "Price outside valid trading band [#{PRICE_BAND_MIN}, #{PRICE_BAND_MAX}]",
        code: 'invalid_price'
      }
    end

    # Could add more checks here:
    # - Trading hours
    # - Symbol-specific restrictions
    # - User-specific limits

    { success: true }
  end

  def check_funds(client_id, amount)
    # In production, this would call the portfolios-service
    # For now, we'll simulate sufficient funds
    # TODO: Implement inter-service call to portfolios-service
    
    Rails.logger.info("[PRETRADE] Checking funds for client #{client_id}: #{amount}")
    { success: true }
  end

  def calculate_cost(order_type, quantity, price, symbol)
    if order_type == 'limit'
      quantity * price
    else
      # For market orders, use estimated price
      quantity * estimated_market_price(symbol)
    end
  end

  def estimated_market_price(symbol)
    # Simplified market price estimation
    prices = {
      'AAPL' => 175.0,
      'MSFT' => 380.0,
      'GOOGL' => 140.0,
      'AMZN' => 185.0,
      'META' => 500.0,
      'TSLA' => 250.0,
      'NVDA' => 480.0
    }
    prices[symbol.upcase] || 100.0
  end
end
