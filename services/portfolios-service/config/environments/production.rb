# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Caching
  config.action_controller.perform_caching = true
  config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1') }

  # Logging
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym
  config.log_tags = [:request_id]

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Active Record
  config.active_record.dump_schema_after_migration = false

  # Force SSL
  config.force_ssl = ENV.fetch('FORCE_SSL', 'false') == 'true'
end
