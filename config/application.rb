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

  end
end
