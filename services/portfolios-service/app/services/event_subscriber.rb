# frozen_string_literal: true

# EventSubscriber - Manages event subscriptions for Portfolios Service
#
module EventSubscriber
  ORDER_REQUESTED = 'order.requested'

  class << self
    def start
      Rails.logger.info('[EventSubscriber] Starting event subscriptions for Portfolios Service...')

      require Rails.root.join('lib/event_bus')
      require Rails.root.join('app/event_handlers/order_handlers')

      @handlers = {
        ORDER_REQUESTED => EventHandlers::OrderRequestedHandler.new,
        EventBus::Events::EXECUTION_REPORT => EventHandlers::ExecutionReportHandler.new,
        EventBus::Events::ORDER_CANCELLED => EventHandlers::OrderCancelledHandler.new
      }

      @subscriber_thread = Thread.new do
        subscribe_to_events
      end

      Rails.logger.info('[EventSubscriber] Event subscriptions started')
    end

    def stop
      @running = false
      @subscriber_thread&.kill
      Rails.logger.info('[EventSubscriber] Event subscriptions stopped')
    end

    private

    def subscribe_to_events
      @running = true

      EventBus.subscribe(
        ORDER_REQUESTED,
        EventBus::Events::EXECUTION_REPORT,
        EventBus::Events::ORDER_CANCELLED
      ) do |event|
        handle_event(event) if @running
      end
    rescue StandardError => e
      Rails.logger.error("[EventSubscriber] Subscription error: #{e.message}")
      sleep 5 # Wait before retry
      retry if @running
    end

    def handle_event(event)
      handler = @handlers[event[:type]]

      if handler
        if EventBus.processed?(event[:id])
          Rails.logger.info("[EventSubscriber] Event #{event[:id]} already processed, skipping")
          return
        end

        handler.handle(event)
        EventBus.mark_processed(event[:id])
      else
        Rails.logger.warn("[EventSubscriber] No handler for event type: #{event[:type]}")
      end
    end
  end
end
