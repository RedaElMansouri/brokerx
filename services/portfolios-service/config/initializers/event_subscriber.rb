# frozen_string_literal: true

# Event Subscriber Initializer for Portfolios Service
# Starts background event listeners for choreographed saga
#

Rails.application.config.after_initialize do
  if defined?(Rails::Server) || ENV['START_EVENT_SUBSCRIBER'] == 'true'
    begin
      require Rails.root.join('lib/event_bus')
      require Rails.root.join('app/services/event_subscriber')
      
      EventSubscriber.start
      Rails.logger.info('[INIT] Event subscriber started for Portfolios Service')
    rescue StandardError => e
      Rails.logger.error("[INIT] Failed to start event subscriber: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
    end
  end

  at_exit do
    EventSubscriber.stop rescue nil
    Rails.logger.info('[SHUTDOWN] Event subscriber stopped')
  end
end
