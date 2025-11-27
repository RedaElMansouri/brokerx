# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'active_job/railtie'

Bundler.require(*Rails.groups)

module PortfoliosService
  class Application < Rails::Application
    config.load_defaults 7.1

    # API-only mode
    config.api_only = true

    # Service identification
    config.service_name = 'portfolios-service'
    config.service_version = '1.0.0'

    # Time zone
    config.time_zone = 'Eastern Time (US & Canada)'

    # Autoload paths
    config.autoload_paths += %W[
      #{config.root}/app/domain
      #{config.root}/app/application
      #{config.root}/app/infrastructure
    ]

    # Active Job queue adapter
    config.active_job.queue_adapter = ENV.fetch('ACTIVE_JOB_BACKEND', 'async').to_sym

    # Logging
    config.log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
    config.log_tags = [:request_id]

    # Secret key base
    config.secret_key_base = ENV.fetch('SECRET_KEY_BASE') { SecureRandom.hex(64) }
  end
end
