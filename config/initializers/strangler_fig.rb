# frozen_string_literal: true

# Configuration for Strangler Fig Pattern
# Determines whether the monolith should delegate to microservices or use local code
module StranglerFig
  class Configuration
    attr_accessor :enabled, :clients_service_enabled, :portfolios_service_enabled, :orders_service_enabled

    def initialize
      @enabled = ENV.fetch('STRANGLER_FIG_ENABLED', 'false') == 'true'
      @clients_service_enabled = ENV.fetch('CLIENTS_SERVICE_ENABLED', 'false') == 'true'
      @portfolios_service_enabled = ENV.fetch('PORTFOLIOS_SERVICE_ENABLED', 'false') == 'true'
      @orders_service_enabled = ENV.fetch('ORDERS_SERVICE_ENABLED', 'false') == 'true'
    end

    def use_microservice?(service)
      return false unless @enabled

      case service
      when :clients
        @clients_service_enabled
      when :portfolios
        @portfolios_service_enabled
      when :orders
        @orders_service_enabled
      else
        false
      end
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def use_microservice?(service)
      configuration.use_microservice?(service)
    end

    def reset!
      @configuration = Configuration.new
    end
  end
end
