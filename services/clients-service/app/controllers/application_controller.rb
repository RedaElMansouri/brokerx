# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :set_request_id

  rescue_from StandardError, with: :handle_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  protected

  def current_client
    @current_client ||= authenticate_client
  end

  def authenticate_client!
    render_unauthorized unless current_client
  end

  private

  def authenticate_client
    authenticate_with_http_token do |token, _options|
      decoded = JwtService.decode(token)
      return nil unless decoded

      Client.find_by(id: decoded[:client_id])
    rescue JWT::DecodeError
      nil
    end
  end

  def set_request_id
    response.headers['X-Request-Id'] = request.request_id
    response.headers['X-Instance-Id'] = ENV.fetch('INSTANCE_ID', 'clients-1')
  end

  def render_unauthorized
    render json: { error: 'Unauthorized', code: 'UNAUTHORIZED' }, status: :unauthorized
  end

  def handle_not_found(exception)
    render json: {
      error: 'Resource not found',
      code: 'NOT_FOUND',
      details: exception.message
    }, status: :not_found
  end

  def handle_validation_error(exception)
    render json: {
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def handle_parameter_missing(exception)
    render json: {
      error: 'Missing required parameter',
      code: 'PARAMETER_MISSING',
      details: exception.message
    }, status: :bad_request
  end

  def handle_internal_error(exception)
    Rails.logger.error("Internal error: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))

    render json: {
      error: 'Internal server error',
      code: 'INTERNAL_ERROR'
    }, status: :internal_server_error
  end
end
