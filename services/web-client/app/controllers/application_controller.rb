# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Disable CSRF for API calls
  skip_before_action :verify_authenticity_token, raise: false

  protected

  def kong_gateway_url
    Rails.application.config.kong_gateway_url
  end
end
