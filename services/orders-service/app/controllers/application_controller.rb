# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  before_action :authenticate_request!

  rescue_from StandardError, with: :handle_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::StaleObjectError, with: :handle_version_conflict
  rescue_from JWT::DecodeError, with: :handle_unauthorized

  protected

  def authenticate_request!
    @current_client = decode_auth_token
  end

  def current_client
    @current_client
  end

  def current_client_id
    @current_client&.dig('client_id')
  end

  def correlation_id
    @correlation_id ||= request.headers['X-Correlation-Id'] || SecureRandom.uuid
  end

  private

  def decode_auth_token
    auth_header = request.headers['Authorization']
    raise JWT::DecodeError, 'Missing Authorization header' unless auth_header

    token = auth_header.split(' ').last
    JwtService.decode(token)
  end

  def handle_internal_error(exception)
    Rails.logger.error("Internal error: #{exception.message}")
    Rails.logger.error(exception.backtrace.first(10).join("\n"))

    render json: {
      success: false,
      error: 'Internal server error',
      message: Rails.env.development? ? exception.message : 'Something went wrong'
    }, status: :internal_server_error
  end

  def handle_not_found(exception)
    render json: {
      success: false,
      error: 'Not found',
      message: exception.message
    }, status: :not_found
  end

  def handle_validation_error(exception)
    render json: {
      success: false,
      errors: exception.record&.errors&.full_messages || [exception.message]
    }, status: :unprocessable_entity
  end

  def handle_version_conflict(_exception)
    render json: {
      success: false,
      code: 'version_conflict',
      message: 'Order has been modified by another process'
    }, status: :conflict
  end

  def handle_unauthorized(exception)
    render json: {
      success: false,
      error: 'Unauthorized',
      message: exception.message || 'Invalid or expired token'
    }, status: :unauthorized
  end
end
