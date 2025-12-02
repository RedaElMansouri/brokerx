# frozen_string_literal: true

module EventHandlers
  # FundsReservedHandler - Handles funds.reserved events from Portfolios Service
  # Part of the choreographed saga for UC-07 (Order Matching)
  #
  # Workflow:
  #   1. Order is placed (status: new)
  #   2. Order waits for funds reservation (status: pending_funds)
  #   3. Portfolios reserves funds → publishes funds.reserved
  #   4. This handler receives event → submits order to matching engine
  #
  class FundsReservedHandler
    def handle(event)
      data = event[:data]
      order_id = data[:order_id]
      correlation_id = event[:correlation_id]

      Rails.logger.info("[FundsReservedHandler] Processing funds.reserved for order #{order_id}")

      order = Order.find_by(id: order_id)
      
      unless order
        Rails.logger.warn("[FundsReservedHandler] Order #{order_id} not found, skipping")
        return
      end

      # Idempotency check - order already processed
      if order.status != 'pending_funds'
        Rails.logger.info("[FundsReservedHandler] Order #{order_id} already processed (status: #{order.status})")
        return
      end

      ActiveRecord::Base.transaction do
        # Update order with reservation info
        order.update!(
          status: 'new',
          reserved_amount: data[:reserved_amount],
          correlation_id: correlation_id
        )

        # Create outbox event for order accepted if OutboxEvent exists
        if defined?(OutboxEvent)
          OutboxEvent.create!(
            aggregate_type: 'Order',
            aggregate_id: order.id,
            event_type: EventBus::Events::ORDER_PLACED,
            payload: {
              order_id: order.id,
              client_id: order.client_id,
              symbol: order.symbol,
              direction: order.direction,
              order_type: order.order_type,
              quantity: order.quantity,
              price: order.price,
              reserved_amount: order.reserved_amount,
              correlation_id: correlation_id,
              timestamp: Time.current.iso8601
            }
          )
        end
      end

      # Submit to matching engine
      MatchingEngine.instance.enqueue_order(order)
      
      Rails.logger.info("[FundsReservedHandler] Order #{order_id} submitted to matching engine")
    rescue StandardError => e
      Rails.logger.error("[FundsReservedHandler] Error processing order #{order_id}: #{e.message}")
      raise
    end
  end

  # FundsReservationFailedHandler - Handles funds.reservation_failed events
  # Compensation: marks order as rejected when funds cannot be reserved
  #
  class FundsReservationFailedHandler
    def handle(event)
      data = event[:data]
      order_id = data[:order_id]
      reason = data[:reason]

      Rails.logger.info("[FundsReservationFailedHandler] Processing for order #{order_id}")

      order = Order.find_by(id: order_id)
      
      unless order
        Rails.logger.warn("[FundsReservationFailedHandler] Order #{order_id} not found")
        return
      end

      return unless order.status == 'pending_funds'

      ActiveRecord::Base.transaction do
        order.update!(
          status: 'rejected',
          rejection_reason: reason || 'Insufficient funds'
        )

        # Create outbox event if OutboxEvent exists
        if defined?(OutboxEvent)
          OutboxEvent.create!(
            aggregate_type: 'Order',
            aggregate_id: order.id,
            event_type: 'order.rejected',
            payload: {
              order_id: order.id,
              client_id: order.client_id,
              reason: order.rejection_reason,
              correlation_id: event[:correlation_id],
              timestamp: Time.current.iso8601
            }
          )
        end
      end

      Rails.logger.info("[FundsReservationFailedHandler] Order #{order_id} rejected: #{reason}")
    end
  end

  # FundsReleasedHandler - Handles funds.released events
  # Confirmation that funds were released after order cancellation
  #
  class FundsReleasedHandler
    def handle(event)
      data = event[:data]
      order_id = data[:order_id]

      Rails.logger.info("[FundsReleasedHandler] Funds released confirmed for order #{order_id}")

      # Log for audit trail - no state change needed
      order = Order.find_by(id: order_id)
      return unless order

      # Could update a funds_released_at timestamp if needed
      Rails.logger.info("[FundsReleasedHandler] Order #{order_id} funds release confirmed")
    end
  end
end
