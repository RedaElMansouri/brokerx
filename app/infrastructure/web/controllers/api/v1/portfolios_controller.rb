module Api
  module V1
    class PortfoliosController < ApplicationController
      skip_before_action :verify_authenticity_token if respond_to?(:skip_before_action)

      def show
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
  return render_api_error(code: 'unauthorized', message: 'Unauthorized', status: :unauthorized) unless client_id

        portfolio = portfolio_repository.find_by_account_id(client_id)
  return render_api_error(code: 'not_found', message: 'Portfolio not found', status: :not_found) unless portfolio

        render json: {
          success: true,
          account_id: portfolio.account_id,
          currency: portfolio.currency,
          available_balance: portfolio.available_balance.amount,
          reserved_balance: portfolio.reserved_balance.amount,
          total_balance: portfolio.total_balance.amount
        }
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
