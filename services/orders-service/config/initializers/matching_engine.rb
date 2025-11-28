# frozen_string_literal: true

# Start the matching engine when the application boots
Rails.application.config.after_initialize do
  if Rails.env.development? || Rails.env.production?
    # Delay start to ensure all dependencies are loaded
    Thread.new do
      sleep 2
      MatchingEngine.instance.start
      Rails.logger.info('[INIT] Matching engine started')
    end
  end
end

# Ensure clean shutdown
at_exit do
  MatchingEngine.instance.stop if MatchingEngine.instance.running?
end
