# frozen_string_literal: true

require_relative '../../../shared/lib/event_bus'

# ChoreographedTradingSaga - Event-driven order placement
# Implements Choreographed Saga pattern for UC-07 (Order Matching)
#
# Instead of synchronous HTTP calls, this saga:
# 1. Creates order with status 'pending_funds'
# 2. Publishes 'order.requested' event
# 3. Portfolios Service listens, reserves funds, publishes 'funds.reserved'
# 4. Orders Service listens, changes status to 'new', submits to matching engine
#
# Benefits:
# - Asynchronous: Services don't need to be available simultaneously
# - Decoupled: Services communicate only via events
# - Resilient: Events are persisted and can be replayed
# - Traceable: All events have correlation IDs for distributed tracing
#
# Flow Diagram:
#
#   Client             Orders Service                 Portfolios Service
#     |                     |                               |
#     | POST /orders        |                               |
#     |-------------------->|                               |
#     |                     |                               |
#     |                     | 1. Create order (pending_funds)
#     |                     |                               |
#     |                     | 2. Publish order.requested    |
#     |                     |=============================>>|
#     |                     |                               |
#     |                     |                    3. Reserve funds
#     |                     |                               |
#     |                     |<<===========================>>|
#     |                     | 4. Receive funds.reserved     |
#     |                     |                               |
#     |                     | 5. Submit to matching engine  |
#     |<--------------------|                               |
#     | 202 Accepted        |                               |
#
class ChoreographedTradingSaga
  class SagaError < StandardError; end
  class ValidationError < SagaError; end

  ORDER_REQUESTED_EVENT = 'order.requested'

  attr_reader :order, :errors

  def initialize
    @errors = []
    @order = nil
  end

  # Execute the saga asynchronously
  # Returns immediately after order is created and event is published
  #
  # @return [Hash] Result with order and status
  def execute(client_id:, symbol:, direction:, order_type:, quantity:, price:, time_in_force:, correlation_id:, idempotency_key:)
    correlation_id ||= SecureRandom.uuid
    Rails.logger.info("[ChoreographedSaga] Starting saga #{correlation_id} for client #{client_id}")

    begin
      # Step 1: Validate inputs
      validate_order!(symbol, direction, order_type, quantity, price)
      Rails.logger.info("[ChoreographedSaga] Validation passed")

      # Step 2: Calculate estimated cost
      estimated_cost = calculate_cost(order_type, quantity, price, symbol)

      # Step 3: Create order in pending_funds state (for buy) or new state (for sell)
      initial_status = direction == 'buy' ? 'pending_funds' : 'new'
      
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
        status: initial_status,
        estimated_cost: estimated_cost
      )
      Rails.logger.info("[ChoreographedSaga] Order #{@order.id} created with status #{initial_status}")

      # Step 4: For buy orders, publish event for fund reservation
      # For sell orders, submit directly to matching engine
      if direction == 'buy'
        publish_order_requested_event(@order, estimated_cost, correlation_id)
        Rails.logger.info("[ChoreographedSaga] Published order.requested event")
      else
        # Sell orders don't need fund reservation - submit directly
        submit_to_matching_engine!(@order)
        Rails.logger.info("[ChoreographedSaga] Sell order submitted to matching engine")
      end

      {
        success: true,
        order: @order,
        correlation_id: correlation_id,
        saga_status: direction == 'buy' ? 'awaiting_funds' : 'submitted',
        message: direction == 'buy' ? 'Order created, awaiting fund reservation' : 'Order submitted to matching engine'
      }
    rescue ValidationError => e
      handle_failure(e, 'validation_failed')
    rescue StandardError => e
      handle_failure(e, 'saga_failed')
    end
  end

  private

  def validate_order!(symbol, direction, order_type, quantity, price)
    errors = []

    valid_symbols = %w[AAPL MSFT GOOGL AMZN META TSLA NVDA]
    errors << "Invalid symbol. Valid symbols: #{valid_symbols.join(', ')}" unless valid_symbols.include?(symbol&.upcase)
    errors << "Direction must be 'buy' or 'sell'" unless %w[buy sell].include?(direction)
    errors << "Order type must be 'market' or 'limit'" unless %w[market limit].include?(order_type)
    errors << "Quantity must be greater than 0" if quantity.nil? || quantity <= 0

    if order_type == 'limit'
      errors << "Price required for limit orders" if price.nil?
      errors << "Price must be between 1 and 10000" if price && (price < 1 || price > 10_000)
    end

    raise ValidationError, errors.join('. ') if errors.any?
  end

  def calculate_cost(order_type, quantity, price, symbol)
    if order_type == 'market'
      market_prices = { 'AAPL' => 175, 'MSFT' => 380, 'GOOGL' => 140, 'AMZN' => 180, 'META' => 500, 'TSLA' => 250, 'NVDA' => 900 }
      estimated_price = market_prices[symbol.upcase] || 100
      quantity * estimated_price * 1.02 # 2% buffer
    else
      quantity * price
    end
  end

  def create_order!(client_id:, symbol:, direction:, order_type:, quantity:, price:, time_in_force:, correlation_id:, idempotency_key:, status:, estimated_cost:)
    ActiveRecord::Base.transaction do
      # Idempotency check
      existing = Order.find_by(idempotency_key: idempotency_key) if idempotency_key.present?
      return existing if existing

      Order.create!(
        client_id: client_id,
        symbol: symbol.upcase,
        direction: direction,
        order_type: order_type,
        quantity: quantity,
        price: order_type == 'limit' ? price : nil,
        time_in_force: time_in_force,
        status: status,
        estimated_cost: estimated_cost,
        correlation_id: correlation_id,
        idempotency_key: idempotency_key
      )
    end
  end

  def publish_order_requested_event(order, estimated_cost, correlation_id)
    # Create outbox event for reliable publishing
    OutboxEvent.create!(
      aggregate_type: 'Order',
      aggregate_id: order.id,
      event_type: ORDER_REQUESTED_EVENT,
      payload: {
        order_id: order.id,
        client_id: order.client_id,
        symbol: order.symbol,
        direction: order.direction,
        order_type: order.order_type,
        quantity: order.quantity,
        price: order.price,
        estimated_cost: estimated_cost,
        correlation_id: correlation_id,
        timestamp: Time.current.iso8601
      }
    )
  end

  def submit_to_matching_engine!(order)
    order.update!(status: 'new')
    MatchingEngine.instance.enqueue_order(order)
  end

  def handle_failure(error, code)
    Rails.logger.error("[ChoreographedSaga] Failed: #{code} - #{error.message}")
    
    {
      success: false,
      error: error.message,
      code: code,
      saga_status: 'failed'
    }
  end
end
