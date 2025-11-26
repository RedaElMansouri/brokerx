# frozen_string_literal: true

class MetricsController < ApplicationController
  skip_before_action :set_request_id, raise: false

  def show
    metrics = generate_prometheus_metrics
    render plain: metrics, content_type: 'text/plain'
  end

  private

  def generate_prometheus_metrics
    <<~METRICS
      # HELP clients_service_clients_total Total number of registered clients
      # TYPE clients_service_clients_total gauge
      clients_service_clients_total #{Client.count rescue 0}

      # HELP clients_service_verified_clients_total Total number of verified clients
      # TYPE clients_service_verified_clients_total gauge
      clients_service_verified_clients_total #{Client.where(email_verified: true).count rescue 0}

      # HELP clients_service_mfa_enabled_total Total number of clients with MFA enabled
      # TYPE clients_service_mfa_enabled_total gauge
      clients_service_mfa_enabled_total #{Client.where(mfa_enabled: true).count rescue 0}

      # HELP clients_service_database_connections Current database connections
      # TYPE clients_service_database_connections gauge
      clients_service_database_connections #{ActiveRecord::Base.connection_pool.connections.size rescue 0}

      # HELP clients_service_uptime_seconds Service uptime in seconds
      # TYPE clients_service_uptime_seconds counter
      clients_service_uptime_seconds #{(Time.current - Rails.application.config.boot_time).to_i rescue 0}
    METRICS
  end
end
