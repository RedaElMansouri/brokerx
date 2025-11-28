# frozen_string_literal: true

class HealthController < ActionController::API
  def show
    render json: {
      status: 'ok',
      service: 'orders-service',
      version: '1.0.0',
      timestamp: Time.current.iso8601
    }
  end

  def ready
    ActiveRecord::Base.connection.execute('SELECT 1')

    render json: {
      status: 'ready',
      service: 'orders-service',
      checks: {
        database: 'ok',
        matching_engine: MatchingEngine.instance.running? ? 'ok' : 'stopped'
      },
      timestamp: Time.current.iso8601
    }
  rescue StandardError => e
    render json: {
      status: 'not_ready',
      service: 'orders-service',
      checks: {
        database: 'error'
      },
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end
