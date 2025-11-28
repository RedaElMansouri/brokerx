# frozen_string_literal: true

# UC-06: Modify Order
# Modifies an existing order with optimistic locking
class ModifyOrderUseCase
  def execute(order:, client_version:, price: nil, quantity: nil, time_in_force: nil)
    # Validate order can be modified
    return error_result('Order cannot be modified', 'invalid_state') unless order.can_modify?

    # Check version for optimistic locking
    if client_version.present? && order.lock_version != client_version.to_i
      return error_result('Order has been modified by another process', 'version_conflict')
    end

    # Calculate new reserved amount for buy orders
    old_reserved = order.reserved_amount || 0
    new_price = price || order.price
    new_quantity = quantity || order.quantity
    new_reserved = order.buy? ? calculate_reserved(new_quantity, new_price) : 0

    # Validate new values
    if quantity && quantity <= 0
      return error_result('Quantity must be greater than 0', 'validation_error')
    end

    if price && price <= 0
      return error_result('Price must be greater than 0', 'validation_error')
    end

    if order.limit_order? && price
      unless valid_price_band?(price)
        return error_result('Price outside valid trading band', 'invalid_price')
      end
    end

    # Update order
    ActiveRecord::Base.transaction do
      order.price = price if price
      order.quantity = quantity if quantity
      order.time_in_force = time_in_force if time_in_force
      order.reserved_amount = new_reserved if order.buy?
      order.save!

      # Create outbox event
      OutboxEvent.create!(
        aggregate_type: 'Order',
        aggregate_id: order.id,
        event_type: 'order.modified',
        payload: {
          order_id: order.id,
          client_id: order.client_id,
          changes: {
            price: price,
            quantity: quantity,
            time_in_force: time_in_force,
            old_reserved: old_reserved,
            new_reserved: new_reserved
          },
          timestamp: Time.current.iso8601
        }
      )
    end

    { success: true, order: order.reload }
  rescue ActiveRecord::StaleObjectError
    error_result('Order has been modified by another process', 'version_conflict')
  rescue StandardError => e
    Rails.logger.error("ModifyOrderUseCase error: #{e.message}")
    error_result(e.message, 'processing_error')
  end

  private

  def calculate_reserved(quantity, price)
    return 0 unless quantity && price
    quantity * price
  end

  def valid_price_band?(price)
    price >= 1.00 && price <= 10_000.00
  end

  def error_result(message, code)
    { success: false, error: message, code: code }
  end
end
