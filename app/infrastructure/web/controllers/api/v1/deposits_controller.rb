# frozen_string_literal: true

# @deprecated This controller is deprecated and will be removed in a future version.
# Deposits are now handled by the portfolios-service microservice.
# This code is kept as a fallback only. Use Kong Gateway (port 8080) for production traffic.
# See: docs/architecture/microservices-architecture.md
module Api
  module V1
    class DepositsController < ApplicationController
      # Endpoints API : pas de vérification CSRF nécessaire
      skip_before_action :verify_authenticity_token

      # @deprecated Use portfolios-service via Kong Gateway instead
      def create
        Rails.logger.warn("[DEPRECATED] DepositsController#create called - use portfolios-service instead")
        # Dépôt de fonds idempotent sur le portefeuille du client
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
  return render_api_error(code: 'unauthorized', message: 'Unauthorized', status: :unauthorized) unless client_id

        amount = params[:amount].to_f
        currency = (params[:currency] || 'USD').to_s
        idempo = request.headers['Idempotency-Key']&.to_s

        use_case = Application::UseCases::DepositFundsUseCase.new(portfolio_repository)
        result = use_case.execute(account_id: client_id, amount: amount, currency: currency, idempotency_key: idempo)

        status_code = result[:reused] ? :ok : :created
        render json: {
          success: true,
          status: result[:status],
          transaction_id: result[:transaction_id],
          balance_after: result[:balance_after]
        }, status: status_code
      rescue ArgumentError => e
        render_api_error(code: 'validation_failed', message: e.message, status: :unprocessable_entity)
      rescue StandardError => e
        render_api_error(code: 'internal_error', message: e.message, status: :internal_server_error)
      end

      def index
        # Liste des dépôts récents (limités) pour le client authentifié
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
  return render_api_error(code: 'unauthorized', message: 'Unauthorized', status: :unauthorized) unless client_id

        txs = ::Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord
              .where(account_id: client_id, operation_type: 'deposit')
              .order(created_at: :desc)
              .limit(20)

        render json: { success: true, deposits: txs.map do |t|
          { id: t.id, amount: t.amount, currency: t.currency, status: t.status, settled_at: t.settled_at }
        end }
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
