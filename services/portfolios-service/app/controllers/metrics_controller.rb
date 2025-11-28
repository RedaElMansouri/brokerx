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
      # HELP portfolios_service_portfolios_total Total number of portfolios
      # TYPE portfolios_service_portfolios_total gauge
      portfolios_service_portfolios_total #{Portfolio.count rescue 0}

      # HELP portfolios_service_total_value Total value across all portfolios
      # TYPE portfolios_service_total_value gauge
      portfolios_service_total_value #{Portfolio.sum(:total_value) rescue 0}

      # HELP portfolios_service_total_cash Total cash across all portfolios
      # TYPE portfolios_service_total_cash gauge
      portfolios_service_total_cash #{Portfolio.sum(:cash) rescue 0}

      # HELP portfolios_service_holdings_total Total number of holdings
      # TYPE portfolios_service_holdings_total gauge
      portfolios_service_holdings_total #{Holding.count rescue 0}

      # HELP portfolios_service_database_connections Current database connections
      # TYPE portfolios_service_database_connections gauge
      portfolios_service_database_connections #{ActiveRecord::Base.connection_pool.connections.size rescue 0}

      # HELP portfolios_service_uptime_seconds Service uptime in seconds
      # TYPE portfolios_service_uptime_seconds counter
      portfolios_service_uptime_seconds #{uptime_seconds}

      # HELP portfolios_service_requests_total Total HTTP requests processed
      # TYPE portfolios_service_requests_total counter
      portfolios_service_requests_total #{request_count}
    METRICS
  end

  def uptime_seconds
    if Rails.application.config.respond_to?(:boot_time)
      (Time.current - Rails.application.config.boot_time).to_i
    else
      0
    end
  rescue StandardError
    0
  end

  def request_count
    Rails.cache.read('portfolios_service_request_count') || 0
  rescue StandardError
    0
  end
end
