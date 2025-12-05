# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  # Disable caching
  config.action_controller.perform_caching = false
  config.cache_classes = false

  # Print deprecation notices
  config.active_support.deprecation = :log

  # Assets
  config.assets.debug = true
  config.assets.quiet = true

  # Logging
  config.log_level = :debug

  # Secret key base
  config.secret_key_base = ENV.fetch('SECRET_KEY_BASE', 'dev_secret_key_base_for_web_client')
end
