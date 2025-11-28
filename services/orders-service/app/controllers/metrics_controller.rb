# frozen_string_literal: true

class MetricsController < ApplicationController
  skip_before_action :authenticate_request!, raise: false
  skip_before_action :set_request_id, raise: false

  def show
    metrics = generate_prometheus_metrics
    render plain: metrics, content_type: 'text/plain'
  end

  private

  def generate_prometheus_metrics
    <<~METRICS
      # HELP orders_service_orders_total Total number of orders
      # TYPE orders_service_orders_total gauge
      orders_service_orders_total #{Order.count rescue 0}

      # HELP orders_service_pending_orders Pending orders count
      # TYPE orders_service_pending_orders gauge
      orders_service_pending_orders #{Order.where(status: 'pending').count rescue 0}

      # HELP orders_service_executed_orders Executed orders count
      # TYPE orders_service_executed_orders gauge
      orders_service_executed_orders #{Order.where(status: 'executed').count rescue 0}

      # HELP orders_service_cancelled_orders Cancelled orders count
      # TYPE orders_service_cancelled_orders gauge
      orders_service_cancelled_orders #{Order.where(status: 'cancelled').count rescue 0}

      # HELP orders_service_buy_orders_total Total buy orders
      # TYPE orders_service_buy_orders_total gauge
      orders_service_buy_orders_total #{Order.where(order_type: 'buy').count rescue 0}

      # HELP orders_service_sell_orders_total Total sell orders
      # TYPE orders_service_sell_orders_total gauge
      orders_service_sell_orders_total #{Order.where(order_type: 'sell').count rescue 0}

      # HELP orders_service_total_volume Total trading volume
      # TYPE orders_service_total_volume gauge
      orders_service_total_volume #{total_volume}

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

  def total_volume
    Order.where(status: 'executed').sum('quantity * price')
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
