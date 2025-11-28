# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  # Allow all hosts in development (for Docker/Kong)
  config.hosts.clear

  # Caching
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Active Record
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true

  # ActionCable
  config.action_cable.url = ENV.fetch('ACTION_CABLE_URL', 'ws://localhost:3003/cable')
  config.action_cable.allowed_request_origins = [/.*/]

  # Logging
  config.log_level = :debug
end
