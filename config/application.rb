require_relative "boot"

require "rails/all"

# Ensure custom middleware constant is available during boot when adding to stack
require_relative "../app/infrastructure/web/middleware/instance_header_middleware"

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
    # Use Rails defaults for autoload/eager load; app/* will be autoloaded and
    # namespaced per folder names (e.g., Application::, Domain::, Infrastructure::).
    # CORS: allow only configured origins (comma-separated). Default to localhost for dev.
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        allowed = ENV.fetch('CORS_ALLOWED_ORIGINS', 'http://localhost:3000')
        origins(*allowed.split(',').map(&:strip))
        resource '*',
                  headers: :any,
                  methods: [:get, :post, :options],
                  expose: ['Authorization'],
                  max_age: 600
      end
    end

  # Annotate responses with instance name for LB observation (set via SERVICE_NAME)
  config.middleware.use Infrastructure::Web::Middleware::InstanceHeaderMiddleware

  end
end
