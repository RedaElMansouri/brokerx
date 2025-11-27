# frozen_string_literal: true

class HealthController < ActionController::API
  def show
    render json: {
      status: 'ok',
      service: 'portfolios-service',
      version: '1.0.0',
      timestamp: Time.current.iso8601
    }
  end

  def ready
    # Check database connection
    ActiveRecord::Base.connection.execute('SELECT 1')

    render json: {
      status: 'ready',
      service: 'portfolios-service',
      checks: {
        database: 'ok'
      },
      timestamp: Time.current.iso8601
    }
  rescue StandardError => e
    render json: {
      status: 'not_ready',
      service: 'portfolios-service',
      checks: {
        database: 'error'
      },
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end
