# frozen_string_literal: true

# UC-08: Orders Channel (WebSocket)
# Real-time order updates and execution reports
class OrdersChannel < ApplicationCable::Channel
  def subscribed
    stream_from "orders_#{current_client_id}"
    Rails.logger.info("[ORDERS] Client #{current_client_id} subscribed to order updates")
  end

  def unsubscribed
    Rails.logger.info("[ORDERS] Client #{current_client_id} unsubscribed")
  end
end
