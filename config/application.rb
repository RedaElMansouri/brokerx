require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
module Brokerx
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true

    # Timezone
    config.time_zone = 'UTC'
    config.active_record.default_timezone = :utc

    # Logging
    config.log_level = :info
    config.autoload_paths += Dir["#{config.root}/app/domain/**/"]
    config.autoload_paths += Dir["#{config.root}/app/application/**/"]
    config.autoload_paths += Dir["#{config.root}/app/infrastructure/**/"]
    config.eager_load_paths += Dir["#{config.root}/app/domain/**/"]
    config.eager_load_paths += Dir["#{config.root}/app/application/**/"]
    config.eager_load_paths += Dir["#{config.root}/app/infrastructure/**/"]
    config.middleware.insert_before 0, Rack::Cors do
      allow do
      origins '*'
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end

  end
end
