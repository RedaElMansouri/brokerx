# frozen_string_literal: true

# EventSubscriber - Manages event subscriptions for Orders Service
# Starts background threads to listen for events from other services
#
module EventSubscriber
  class << self
    def start
      Rails.logger.info('[EventSubscriber] Starting event subscriptions for Orders Service...')

      require Rails.root.join('lib/event_bus')
      require Rails.root.join('app/event_handlers/funds_handlers')

      @handlers = {
        EventBus::Events::FUNDS_RESERVED => EventHandlers::FundsReservedHandler.new,
        EventBus::Events::FUNDS_RESERVATION_FAILED => EventHandlers::FundsReservationFailedHandler.new,
        EventBus::Events::FUNDS_RELEASED => EventHandlers::FundsReleasedHandler.new
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
        EventBus::Events::FUNDS_RESERVED,
        EventBus::Events::FUNDS_RESERVATION_FAILED,
        EventBus::Events::FUNDS_RELEASED
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
        # Check idempotency
        if EventBus.processed?(event[:id])
          Rails.logger.info("[EventSubscriber] Event #{event[:id]} already processed, skipping")
          return
        end

        handler.handle(event)
      else
        Rails.logger.warn("[EventSubscriber] No handler for event type: #{event[:type]}")
      end
    end
  end
end
