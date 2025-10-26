class OrdersChannel < ApplicationCable::Channel
  # Client subscribes with params: {}
  def subscribed
    client_id = connection.current_client_id
    reject unless client_id

    stream_from "orders:#{client_id}"
  end

  def unsubscribed
  end
end
