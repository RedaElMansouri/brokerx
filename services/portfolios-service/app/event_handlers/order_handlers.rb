# frozen_string_literal: true

require_relative '../../lib/event_bus'

module EventHandlers
  # OrderRequestedHandler - Handles order.requested events for fund reservation
  # Part of UC-07 choreographed saga
  #
  # When Orders Service creates a new order, it publishes order.requested
  # This handler reserves the required funds and responds with funds.reserved
  #
  class OrderRequestedHandler
    def handle(event)
      data = event[:data]
      client_id = data[:client_id]
      order_id = data[:order_id]
      amount = data[:estimated_cost] || data[:reserved_amount]
      direction = data[:direction]
      correlation_id = event[:correlation_id]

      Rails.logger.info("[OrderRequestedHandler] Processing order #{order_id} for client #{client_id}")

      # Only reserve funds for buy orders
      unless direction == 'buy'
        publish_funds_reserved(order_id, client_id, 0, correlation_id)
        return
      end

      portfolio = Portfolio.find_by(client_id: client_id)
      
      unless portfolio
        publish_reservation_failed(order_id, client_id, 'Portfolio not found', correlation_id)
        return
      end

      # Idempotency - check if already reserved
      existing_reservation = portfolio.fund_reservations.find_by(order_id: order_id)
      if existing_reservation
        Rails.logger.info("[OrderRequestedHandler] Reservation already exists for order #{order_id}")
        publish_funds_reserved(order_id, client_id, existing_reservation.amount, correlation_id)
        return
      end

      # Try to reserve funds
      if portfolio.available_balance >= amount
        ActiveRecord::Base.transaction do
          # Create reservation record
          portfolio.fund_reservations.create!(
            order_id: order_id,
            amount: amount,
            status: 'reserved',
            correlation_id: correlation_id
          )

          # Update portfolio
          portfolio.update!(
            reserved_balance: portfolio.reserved_balance + amount,
            available_balance: portfolio.available_balance - amount
          )

          Rails.logger.info("[OrderRequestedHandler] Reserved $#{amount} for order #{order_id}")
        end

        publish_funds_reserved(order_id, client_id, amount, correlation_id)
      else
        Rails.logger.warn("[OrderRequestedHandler] Insufficient funds for order #{order_id}")
        publish_reservation_failed(
          order_id, 
          client_id, 
          "Insufficient funds. Required: $#{amount}, Available: $#{portfolio.available_balance}",
          correlation_id
        )
      end
    rescue StandardError => e
      Rails.logger.error("[OrderRequestedHandler] Error: #{e.message}")
      publish_reservation_failed(order_id, client_id, e.message, correlation_id) if order_id
      raise
    end

    private

    def publish_funds_reserved(order_id, client_id, amount, correlation_id)
      EventBus.publish(
        EventBus::Events::FUNDS_RESERVED,
        {
          order_id: order_id,
          client_id: client_id,
          reserved_amount: amount,
          timestamp: Time.current.iso8601
        },
        correlation_id: correlation_id
      )
    end

    def publish_reservation_failed(order_id, client_id, reason, correlation_id)
      EventBus.publish(
        EventBus::Events::FUNDS_RESERVATION_FAILED,
        {
          order_id: order_id,
          client_id: client_id,
          reason: reason,
          timestamp: Time.current.iso8601
        },
        correlation_id: correlation_id
      )
    end
  end

  # ExecutionReportHandler - Handles execution reports from Orders Service
  # Updates portfolio positions after trade execution
  #
  class ExecutionReportHandler
    def handle(event)
      data = event[:data]
      order_id = data[:order_id]
      status = data[:status]
      correlation_id = event[:correlation_id]

      Rails.logger.info("[ExecutionReportHandler] Processing execution report for order #{order_id}, status: #{status}")

      case status
      when 'filled', 'partially_filled'
        process_fill(data, correlation_id)
      when 'cancelled', 'rejected'
        release_funds(data, correlation_id)
      when 'working'
        # No action needed - order is in the book
        Rails.logger.info("[ExecutionReportHandler] Order #{order_id} is working")
      end
    end

    private

    def process_fill(data, correlation_id)
      client_id = data[:client_id]
      order_id = data[:order_id]
      symbol = data[:symbol]
      quantity = data[:quantity]
      price = data[:price]
      direction = data[:direction]

      portfolio = Portfolio.find_by(client_id: client_id)
      return unless portfolio

      ActiveRecord::Base.transaction do
        # Find or create position
        position = portfolio.positions.find_or_initialize_by(symbol: symbol)
        
        if direction == 'buy'
          # Update position (add shares)
          position.quantity = (position.quantity || 0) + quantity
          position.average_cost = calculate_average_cost(position, quantity, price)
          position.save!

          # Release reserved funds (actual cost)
          actual_cost = quantity * price
          release_reservation(portfolio, order_id, actual_cost)
        else
          # Sell - reduce position, credit funds
          position.quantity = (position.quantity || 0) - quantity
          position.save!
          
          # Credit sale proceeds
          proceeds = quantity * price
          portfolio.update!(
            cash_balance: portfolio.cash_balance + proceeds,
            available_balance: portfolio.available_balance + proceeds
          )
        end

        # Publish position update
        EventBus.publish(
          EventBus::Events::POSITION_UPDATED,
          {
            client_id: client_id,
            symbol: symbol,
            quantity: position.quantity,
            average_cost: position.average_cost,
            timestamp: Time.current.iso8601
          },
          correlation_id: correlation_id
        )

        Rails.logger.info("[ExecutionReportHandler] Updated position for #{symbol}: #{position.quantity} shares")
      end
    end

    def release_funds(data, correlation_id)
      client_id = data[:client_id]
      order_id = data[:order_id]

      portfolio = Portfolio.find_by(client_id: client_id)
      return unless portfolio

      reservation = portfolio.fund_reservations.find_by(order_id: order_id, status: 'reserved')
      return unless reservation

      ActiveRecord::Base.transaction do
        # Release the full reserved amount
        amount = reservation.amount

        portfolio.update!(
          reserved_balance: portfolio.reserved_balance - amount,
          available_balance: portfolio.available_balance + amount
        )

        reservation.update!(status: 'released')

        EventBus.publish(
          EventBus::Events::FUNDS_RELEASED,
          {
            order_id: order_id,
            client_id: client_id,
            amount: amount,
            timestamp: Time.current.iso8601
          },
          correlation_id: correlation_id
        )

        Rails.logger.info("[ExecutionReportHandler] Released $#{amount} for cancelled order #{order_id}")
      end
    end

    def release_reservation(portfolio, order_id, actual_cost)
      reservation = portfolio.fund_reservations.find_by(order_id: order_id, status: 'reserved')
      return unless reservation

      # Release excess if any
      excess = reservation.amount - actual_cost
      
      if excess > 0
        portfolio.update!(
          reserved_balance: portfolio.reserved_balance - excess,
          available_balance: portfolio.available_balance + excess
        )
      end

      reservation.update!(
        status: 'settled',
        settled_amount: actual_cost
      )
    end

    def calculate_average_cost(position, new_quantity, new_price)
      existing_quantity = position.quantity || 0
      existing_cost = (position.average_cost || 0) * existing_quantity
      new_cost = new_quantity * new_price
      
      total_quantity = existing_quantity + new_quantity
      return new_price if total_quantity.zero?
      
      (existing_cost + new_cost) / total_quantity
    end
  end

  # OrderCancelledHandler - Handles order cancellation events
  # Releases reserved funds when orders are cancelled
  #
  class OrderCancelledHandler
    def handle(event)
      data = event[:data]
      order_id = data[:order_id]
      client_id = data[:client_id]
      correlation_id = event[:correlation_id]

      Rails.logger.info("[OrderCancelledHandler] Processing cancellation for order #{order_id}")

      portfolio = Portfolio.find_by(client_id: client_id)
      return unless portfolio

      reservation = portfolio.fund_reservations.find_by(order_id: order_id, status: 'reserved')
      return unless reservation

      ActiveRecord::Base.transaction do
        amount = reservation.amount

        portfolio.update!(
          reserved_balance: portfolio.reserved_balance - amount,
          available_balance: portfolio.available_balance + amount
        )

        reservation.update!(status: 'released')

        EventBus.publish(
          EventBus::Events::FUNDS_RELEASED,
          {
            order_id: order_id,
            client_id: client_id,
            amount: amount,
            reason: 'order_cancelled',
            timestamp: Time.current.iso8601
          },
          correlation_id: correlation_id
        )

        Rails.logger.info("[OrderCancelledHandler] Released $#{amount} for order #{order_id}")
      end
    end
  end
end
