# frozen_string_literal: true

class MetricsController < ApplicationController
  skip_before_action :authenticate_request!, raise: false
  skip_before_action :set_request_id, raise: false

  # Cache metrics for 10 seconds to avoid overloading the database
  CACHE_TTL = 10.seconds

  def show
    metrics = Rails.cache.fetch('prometheus_metrics', expires_in: CACHE_TTL) do
      generate_prometheus_metrics
    end
    render plain: metrics, content_type: 'text/plain'
  end

  private

  def generate_prometheus_metrics
    # Collect all metrics data in a single pass
    stats = collect_order_stats

    <<~METRICS
      # HELP orders_service_orders_total Total number of orders
      # TYPE orders_service_orders_total gauge
      orders_service_orders_total #{stats[:total]}

      # HELP orders_service_pending_orders Pending orders count
      # TYPE orders_service_pending_orders gauge
      orders_service_pending_orders #{stats[:pending]}

      # HELP orders_service_executed_orders Executed orders count
      # TYPE orders_service_executed_orders gauge
      orders_service_executed_orders #{stats[:executed]}

      # HELP orders_service_cancelled_orders Cancelled orders count
      # TYPE orders_service_cancelled_orders gauge
      orders_service_cancelled_orders #{stats[:cancelled]}

      # HELP orders_service_buy_orders_total Total buy orders
      # TYPE orders_service_buy_orders_total gauge
      orders_service_buy_orders_total #{stats[:buy]}

      # HELP orders_service_sell_orders_total Total sell orders
      # TYPE orders_service_sell_orders_total gauge
      orders_service_sell_orders_total #{stats[:sell]}

      # HELP orders_service_total_volume Total trading volume
      # TYPE orders_service_total_volume gauge
      orders_service_total_volume #{stats[:volume]}

      # HELP orders_service_database_connections Current database connections
      # TYPE orders_service_database_connections gauge
      orders_service_database_connections #{ActiveRecord::Base.connection_pool.connections.size rescue 0}

      # HELP orders_service_uptime_seconds Service uptime in seconds
      # TYPE orders_service_uptime_seconds counter
      orders_service_uptime_seconds #{uptime_seconds}

      # HELP orders_service_requests_total Total HTTP requests processed
      # TYPE orders_service_requests_total counter
      orders_service_requests_total #{request_count}
    METRICS
  end

  def collect_order_stats
    # Use a single optimized query to get all counts
    status_counts = Order.group(:status).count rescue {}
    type_counts = Order.group(:order_type).count rescue {}
    
    {
      total: status_counts.values.sum,
      pending: status_counts['pending'] || 0,
      executed: (status_counts['filled'] || 0) + (status_counts['partially_filled'] || 0),
      cancelled: status_counts['cancelled'] || 0,
      buy: type_counts['buy'] || 0,
      sell: type_counts['sell'] || 0,
      volume: calculate_volume
    }
  rescue StandardError => e
    Rails.logger.error("Metrics collection error: #{e.message}")
    { total: 0, pending: 0, executed: 0, cancelled: 0, buy: 0, sell: 0, volume: 0 }
  end

  def calculate_volume
    # Calculate volume from trades table (actual executed trades)
    Trade.sum('quantity * price')
  rescue StandardError
    0
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
    Rails.cache.read('orders_service_request_count') || 0
  rescue StandardError
    0
  end
end
