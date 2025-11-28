# frozen_string_literal: true

# UC-06: Cancel Order
# Cancels an existing order with optimistic locking
class CancelOrderUseCase
  def execute(order:, client_version: nil)
    # Validate order can be cancelled
    return error_result('Order cannot be cancelled', 'invalid_state') unless order.can_cancel?

    # Check version for optimistic locking
    if client_version.present? && order.lock_version != client_version.to_i
      return error_result('Order has been modified by another process', 'version_conflict')
    end

    reserved_amount = order.reserved_amount || 0

    ActiveRecord::Base.transaction do
      order.status = 'cancelled'
      order.reserved_amount = 0
      order.save!

      # Create outbox event
      OutboxEvent.create!(
        aggregate_type: 'Order',
        aggregate_id: order.id,
        event_type: 'order.cancelled',
        payload: {
          order_id: order.id,
          client_id: order.client_id,
          symbol: order.symbol,
          released_amount: reserved_amount,
          timestamp: Time.current.iso8601
        }
      )
    end

    # Remove from matching engine
    MatchingEngine.instance.remove_order(order.id)

    { success: true, order: order.reload }
  rescue ActiveRecord::StaleObjectError
    error_result('Order has been modified by another process', 'version_conflict')
  rescue StandardError => e
    Rails.logger.error("CancelOrderUseCase error: #{e.message}")
    error_result(e.message, 'processing_error')
  end

  private

  def error_result(message, code)
    { success: false, error: message, code: code }
  end
end
