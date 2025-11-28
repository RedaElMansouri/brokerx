# frozen_string_literal: true

require_relative 'boot'
require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_cable/engine'

Bundler.require(*Rails.groups)

module OrdersService
  class Application < Rails::Application
    config.load_defaults 7.1
    config.autoload_lib(ignore: %w[assets tasks])

    # API-only mode
    config.api_only = true

    # Autoload paths
    config.autoload_paths += %W[
      #{config.root}/app/use_cases
      #{config.root}/app/services
      #{config.root}/app/channels
    ]

    # Time zone
    config.time_zone = 'Eastern Time (US & Canada)'

    # Generators
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # ActionCable
    config.action_cable.disable_request_forgery_protection = true
  end
end
