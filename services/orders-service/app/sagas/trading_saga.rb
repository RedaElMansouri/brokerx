# frozen_string_literal: true

# TradingSaga - Orchestrates order placement with compensation
# Implements Saga pattern for distributed transactions across Orders & Portfolios services
#
# Saga Steps:
#   1. Validate order parameters
#   2. Reserve funds (call Portfolios service)
#   3. Create order in database
#   4. Submit to matching engine
#
# Compensation (on failure):
#   - Release reserved funds
#   - Mark order as rejected
#
class TradingSaga
  class SagaError < StandardError; end
  class ValidationError < SagaError; end
  class FundsReservationError < SagaError; end
  class OrderCreationError < SagaError; end

  attr_reader :order, :errors

  def initialize
    @portfolios_client = PortfoliosClient.new
    @errors = []
    @funds_reserved = false
    @order = nil
  end

  def execute(client_id:, symbol:, direction:, order_type:, quantity:, price:, time_in_force:, correlation_id:, idempotency_key:)
    Rails.logger.info("[TradingSaga] Starting saga for client #{client_id}, symbol #{symbol}")

    begin
      # Step 1: Validate
      validate_order!(symbol, direction, order_type, quantity, price)
      Rails.logger.info("[TradingSaga] Step 1/4: Validation passed")

      # Step 2: Reserve funds (for buy orders)
      estimated_cost = calculate_cost(order_type, quantity, price, symbol)
      if direction == 'buy'
        reserve_funds!(client_id, estimated_cost, correlation_id)
        Rails.logger.info("[TradingSaga] Step 2/4: Funds reserved (#{estimated_cost})")
      else
        Rails.logger.info("[TradingSaga] Step 2/4: Skipped (sell order)")
      end

      # Step 3: Create order
      @order = create_order!(
        client_id: client_id,
        symbol: symbol,
        direction: direction,
        order_type: order_type,
        quantity: quantity,
        price: price,
        time_in_force: time_in_force,
        correlation_id: correlation_id,
        idempotency_key: idempotency_key,
        reserved_amount: direction == 'buy' ? estimated_cost : 0
      )
      Rails.logger.info("[TradingSaga] Step 3/4: Order created (#{@order.id})")

      # Step 4: Submit to matching engine
      submit_to_matching_engine!(@order)
      Rails.logger.info("[TradingSaga] Step 4/4: Submitted to matching engine")

      {
        success: true,
        order: @order,
        correlation_id: correlation_id,
        saga_status: 'completed'
      }
    rescue ValidationError => e
      handle_failure(e, 'validation_failed')
    rescue FundsReservationError => e
      handle_failure(e, 'funds_reservation_failed')
    rescue OrderCreationError => e
      compensate!(client_id, estimated_cost, correlation_id) if @funds_reserved
      handle_failure(e, 'order_creation_failed')
    rescue StandardError => e
      compensate!(client_id, estimated_cost, correlation_id) if @funds_reserved
      handle_failure(e, 'saga_failed')
    end
  end

  private

  def validate_order!(symbol, direction, order_type, quantity, price)
    errors = []

    valid_symbols = %w[AAPL MSFT GOOGL AMZN META TSLA NVDA]
    errors << "Invalid symbol" unless valid_symbols.include?(symbol&.upcase)
    errors << "Invalid direction" unless %w[buy sell].include?(direction)
    errors << "Invalid order type" unless %w[market limit].include?(order_type)
    errors << "Quantity must be positive" if quantity.nil? || quantity <= 0

    if order_type == 'limit'
      errors << "Price required for limit orders" if price.nil?
      errors << "Price must be between 1 and 10000" if price && (price < 1 || price > 10_000)
    end

    raise ValidationError, errors.join(', ') if errors.any?
  end

  def calculate_cost(order_type, quantity, price, symbol)
    if order_type == 'market'
      # Use estimated market price
      market_prices = { 'AAPL' => 175, 'MSFT' => 380, 'GOOGL' => 140, 'AMZN' => 180, 'META' => 500, 'TSLA' => 250, 'NVDA' => 900 }
      estimated_price = market_prices[symbol.upcase] || 100
      quantity * estimated_price * 1.02 # 2% buffer for market orders
    else
      quantity * price
    end
  end

  def reserve_funds!(client_id, amount, order_id)
    result = @portfolios_client.reserve_funds(
      client_id: client_id,
      amount: amount,
      order_id: order_id
    )

    if result[:success]
      @funds_reserved = true
    else
      raise FundsReservationError, result[:error] || 'Failed to reserve funds'
    end
  rescue PortfoliosClient::InsufficientFundsError => e
    raise FundsReservationError, e.message
  rescue PortfoliosClient::ServiceUnavailableError => e
    raise FundsReservationError, "Portfolios service unavailable: #{e.message}"
  end

  def create_order!(client_id:, symbol:, direction:, order_type:, quantity:, price:, time_in_force:, correlation_id:, idempotency_key:, reserved_amount:)
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
        reserved_amount: reserved_amount,
        correlation_id: correlation_id,
        idempotency_key: idempotency_key
      )

      # Create outbox event
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
          saga_id: correlation_id,
          timestamp: Time.current.iso8601
        }
      )

      order
    end
  rescue ActiveRecord::RecordInvalid => e
    raise OrderCreationError, e.message
  end

  def submit_to_matching_engine!(order)
    MatchingEngine.instance.enqueue_order(order)
  end

  def compensate!(client_id, amount, order_id)
    Rails.logger.warn("[TradingSaga] Compensating: releasing funds for #{order_id}")

    begin
      @portfolios_client.release_funds(
        client_id: client_id,
        amount: amount,
        order_id: order_id
      )
      Rails.logger.info("[TradingSaga] Compensation successful")
    rescue StandardError => e
      Rails.logger.error("[TradingSaga] Compensation failed: #{e.message}")
      # Log for manual intervention but don't raise
    end
  end

  def handle_failure(error, code)
    Rails.logger.error("[TradingSaga] Failed: #{code} - #{error.message}")
    
    {
      success: false,
      error: error.message,
      code: code,
      saga_status: 'failed'
    }
  end
end
