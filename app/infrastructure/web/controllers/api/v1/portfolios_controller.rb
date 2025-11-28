# frozen_string_literal: true

# @deprecated This controller is deprecated and will be removed in a future version.
# Portfolios are now handled by the portfolios-service microservice.
# This code is kept as a fallback only. Use Kong Gateway (port 8080) for production traffic.
# See: docs/architecture/microservices-architecture.md
module Api
  module V1
    class PortfoliosController < ApplicationController
      skip_before_action :verify_authenticity_token if respond_to?(:skip_before_action)

      # @deprecated Use portfolios-service via Kong Gateway instead
      def show
        Rails.logger.warn("[DEPRECATED] PortfoliosController#show called - use portfolios-service instead")
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
  return render_api_error(code: 'unauthorized', message: 'Unauthorized', status: :unauthorized) unless client_id
        # Support cache bypass with header: Cache-Control: no-cache
        bypass = request.headers['Cache-Control']&.downcase&.include?('no-cache')
        cache_key = "portfolio:#{client_id}:v1"
        data = nil
        hit = false

        unless bypass
          data = Rails.cache.read(cache_key)
          hit = !data.nil?
          Infrastructure::Observability::Metrics.inc_counter('cache_portfolio_total', { status: hit ? 'hit' : 'miss' }) if defined?(Infrastructure::Observability::Metrics)
        end

        unless data
          portfolio = portfolio_repository.find_by_account_id(client_id)
    return render_api_error(code: 'not_found', message: 'Portfolio not found', status: :not_found) unless portfolio
          data = {
            success: true,
            account_id: portfolio.account_id,
            currency: portfolio.currency,
            available_balance: portfolio.available_balance.amount,
            reserved_balance: portfolio.reserved_balance.amount,
            total_balance: portfolio.total_balance.amount
          }
          Rails.cache.write(cache_key, data, expires_in: 60.seconds) unless bypass
        end

        response.set_header('X-Cache', hit ? 'HIT' : 'MISS')
        render json: data
      rescue StandardError => e
        render_api_error(code: 'internal_error', message: e.message, status: :internal_server_error)
      end

      private

      def token_to_client_id(token)
        return nil unless token

        begin
          payload, = JWT.decode(
            token,
            Rails.application.secret_key_base,
            true,
            {
              algorithm: 'HS256',
              iss: 'brokerx',
              verify_iss: true,
              aud: 'brokerx.web',
              verify_aud: true,
              verify_expiration: true
            }
          )
          payload['client_id']
        rescue JWT::DecodeError
          nil
        end
      end

      def portfolio_repository
        @portfolio_repository ||= ::Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
      end
    end
  end
end
