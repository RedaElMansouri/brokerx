# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Assets
  config.assets.compile = false
  config.assets.digest = true

  # Logging
  config.log_level = :info
  config.log_tags = [:request_id]

  # Secret key base
  config.secret_key_base = ENV.fetch('SECRET_KEY_BASE')

  # Force SSL
  config.force_ssl = ENV.fetch('FORCE_SSL', 'false') == 'true'
end
