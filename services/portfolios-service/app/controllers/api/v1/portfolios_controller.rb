# frozen_string_literal: true

module Api
  module V1
    class PortfoliosController < ApplicationController
      # GET /api/v1/portfolios
      def index
        portfolios = Portfolio.where(client_id: current_client_id)

        render json: {
          data: portfolios.map { |p| portfolio_json(p) },
          meta: {
            count: portfolios.count
          }
        }
      end

      # GET /api/v1/portfolios/:id
      def show
        portfolio = find_portfolio

        render json: {
          data: portfolio_json(portfolio)
        }
      end

      # POST /api/v1/portfolios
      def create
        use_case = CreatePortfolioUseCase.new
        result = use_case.execute(
          client_id: current_client_id,
          name: params[:name],
          currency: params[:currency] || 'CAD'
        )

        if result[:success]
          render json: {
            data: portfolio_json(result[:portfolio]),
            message: 'Portfolio created successfully'
          }, status: :created
        else
          render json: {
            error: 'Failed to create portfolio',
            message: result[:error]
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/portfolios/:id/balance
      def balance
        portfolio = find_portfolio

        render json: {
          data: {
            portfolio_id: portfolio.id,
            cash_balance: portfolio.cash_balance.to_f,
            currency: portfolio.currency,
            updated_at: portfolio.updated_at.iso8601
          }
        }
      end

      # GET /api/v1/portfolios/:id/transactions
      def transactions
        portfolio = find_portfolio
        transactions = portfolio.portfolio_transactions
                                .order(created_at: :desc)
                                .limit(params[:limit] || 50)

        render json: {
          data: transactions.map { |t| transaction_json(t) },
          meta: {
            portfolio_id: portfolio.id,
            count: transactions.count
          }
        }
      end

      private

      def find_portfolio
        Portfolio.find_by!(id: params[:id], client_id: current_client_id)
      end

      def portfolio_json(portfolio)
        {
          id: portfolio.id,
          client_id: portfolio.client_id,
          name: portfolio.name,
          cash_balance: portfolio.cash_balance.to_f,
          currency: portfolio.currency,
          status: portfolio.status,
          created_at: portfolio.created_at.iso8601,
          updated_at: portfolio.updated_at.iso8601
        }
      end

      def transaction_json(transaction)
        {
          id: transaction.id,
          type: transaction.transaction_type,
          amount: transaction.amount.to_f,
          currency: transaction.currency,
          status: transaction.status,
          idempotency_key: transaction.idempotency_key,
          created_at: transaction.created_at.iso8601
        }
      end
    end
  end
end
