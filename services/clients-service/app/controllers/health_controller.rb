# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :set_request_id, raise: false

  def show
    health_status = {
      status: 'healthy',
      service: 'clients-service',
      version: Rails.application.config.service_version,
      timestamp: Time.current.iso8601,
      checks: {
        database: database_healthy?,
        redis: redis_healthy?
      }
    }

    overall_healthy = health_status[:checks].values.all?
    health_status[:status] = overall_healthy ? 'healthy' : 'degraded'

    render json: health_status, status: overall_healthy ? :ok : :service_unavailable
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError
    false
  end

  def redis_healthy?
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    redis.ping == 'PONG'
  rescue StandardError
    false
  ensure
    redis&.close
  end
end
