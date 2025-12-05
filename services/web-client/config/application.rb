# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)

module WebClient
  class Application < Rails::Application
    config.load_defaults 7.1

    # Don't generate unnecessary files
    config.generators.system_tests = nil

    # API host configuration
    config.kong_gateway_url = ENV.fetch('KONG_GATEWAY_URL', 'http://localhost:8080')

    # Session configuration for auth token storage
    config.session_store :cookie_store, key: '_web_client_session'
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore

    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
                 headers: :any,
                 methods: %i[get post put patch delete options head]
      end
    end
  end
end
