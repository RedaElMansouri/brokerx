# frozen_string_literal: true

module Api
  module V1
    class DepositsController < ApplicationController
      before_action :validate_idempotency_key, only: [:create]

      # GET /api/v1/deposits
      def index
        portfolio = find_default_portfolio
        
        deposits = portfolio.portfolio_transactions
                           .where(transaction_type: 'deposit')
                           .order(created_at: :desc)
                           .limit(params[:limit] || 50)

        render json: {
          data: deposits.map { |d| deposit_json(d) },
          meta: {
            portfolio_id: portfolio.id,
            count: deposits.count
          }
        }
      end

      # GET /api/v1/deposits/:id
      def show
        deposit = find_deposit

        render json: {
          data: deposit_json(deposit)
        }
      end

      # POST /api/v1/deposits (UC-03 - Dépôt de fonds idempotent)
      def create
        use_case = DepositFundsUseCase.new
        result = use_case.execute(
          client_id: current_client_id,
          amount: params[:amount].to_f,
          currency: params[:currency] || 'CAD',
          idempotency_key: idempotency_key,
          portfolio_id: params[:portfolio_id]
        )

        if result[:success]
          status = result[:already_processed] ? :ok : :created
          render json: {
            data: deposit_json(result[:transaction]),
            message: result[:message],
            idempotent: result[:already_processed] || false
          }, status: status
        else
          render json: {
            error: 'Deposit failed',
            message: result[:error],
            code: result[:code]
          }, status: error_status(result[:code])
        end
      end

      private

      def idempotency_key
        @idempotency_key ||= request.headers['Idempotency-Key']
      end

      def validate_idempotency_key
        return if idempotency_key.present?

        render json: {
          error: 'Missing Idempotency-Key',
          message: 'Idempotency-Key header is required for deposit operations'
        }, status: :bad_request
      end

      def find_default_portfolio
        Portfolio.find_by!(client_id: current_client_id)
      end

      def find_deposit
        PortfolioTransaction.joins(:portfolio)
                           .where(portfolios: { client_id: current_client_id })
                           .where(transaction_type: 'deposit')
                           .find(params[:id])
      end

      def deposit_json(transaction)
        {
          id: transaction.id,
          portfolio_id: transaction.portfolio_id,
          amount: transaction.amount.to_f,
          currency: transaction.currency,
          status: transaction.status,
          idempotency_key: transaction.idempotency_key,
          processed_at: transaction.processed_at&.iso8601,
          created_at: transaction.created_at.iso8601
        }
      end

      def error_status(code)
        case code
        when 'invalid_amount' then :unprocessable_entity
        when 'portfolio_not_found' then :not_found
        when 'insufficient_funds' then :unprocessable_entity
        when 'duplicate_key_conflict' then :conflict
        else :internal_server_error
        end
      end
    end
  end
end
