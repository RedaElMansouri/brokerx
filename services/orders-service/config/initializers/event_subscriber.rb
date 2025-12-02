# frozen_string_literal: true

# Event Subscriber Initializer for Orders Service
# Starts background event listeners for choreographed saga
#
# This initializer starts a background thread that listens for events
# from other services (e.g., funds.reserved from Portfolios Service)
#

Rails.application.config.after_initialize do
  # Only start event subscriber in server mode, not in rake tasks or console
  if defined?(Rails::Server) || ENV['START_EVENT_SUBSCRIBER'] == 'true'
    begin
      # Load EventBus from lib folder
      require Rails.root.join('lib/event_bus')
      
      # Load and start event subscriber
      require Rails.root.join('app/services/event_subscriber')
      EventSubscriber.start
      Rails.logger.info('[INIT] Event subscriber started for Orders Service')
    rescue StandardError => e
      Rails.logger.error("[INIT] Failed to start event subscriber: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
    end
  end

  # Graceful shutdown
  at_exit do
    EventSubscriber.stop rescue nil
    Rails.logger.info('[SHUTDOWN] Event subscriber stopped')
  end
end
