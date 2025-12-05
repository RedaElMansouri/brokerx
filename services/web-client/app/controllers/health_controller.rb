# frozen_string_literal: true

class HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      service: 'web-client',
      timestamp: Time.current.iso8601
    }
  end
end
