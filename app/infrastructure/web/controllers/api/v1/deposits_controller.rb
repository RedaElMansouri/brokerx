module Api
  module V1
    class DepositsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        amount = params[:amount].to_f
        currency = (params[:currency] || 'USD').to_s
        idempo = request.headers['Idempotency-Key']&.to_s

        use_case = Application::UseCases::DepositFundsUseCase.new(portfolio_repository)
        result = use_case.execute(account_id: client_id, amount: amount, currency: currency, idempotency_key: idempo)

        render json: { success: true, status: result[:status], transaction_id: result[:transaction_id] }
      rescue StandardError => e
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end

      def index
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        txs = ::Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord
              .where(account_id: client_id, operation_type: 'deposit')
              .order(created_at: :desc)
              .limit(20)

        render json: { success: true, deposits: txs.map do |t|
          { id: t.id, amount: t.amount, currency: t.currency, status: t.status, settled_at: t.settled_at }
        end }
      rescue StandardError => e
        render json: { success: false, error: e.message }, status: :internal_server_error
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
