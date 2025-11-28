# frozen_string_literal: true

module Internal
  # Internal API for fund operations
  # Called by Orders Service for TradingSaga (reserve/release/debit)
  class FundsController < ActionController::API
    before_action :authenticate_internal_request!

    # POST /internal/reserve
    # Reserve funds for a pending order
    def reserve
      client_id = params[:client_id]
      amount = params[:amount].to_f
      order_id = params[:order_id]

      portfolio = Portfolio.find_by(client_id: client_id)

      unless portfolio
        render json: { success: false, error: 'Portfolio not found' }, status: :not_found
        return
      end

      if portfolio.available_balance < amount
        render json: {
          success: false,
          error: 'Insufficient funds',
          available: portfolio.available_balance,
          required: amount
        }, status: :unprocessable_entity
        return
      end

      # Reserve the funds
      ActiveRecord::Base.transaction do
        portfolio.update!(
          reserved_amount: portfolio.reserved_amount + amount
        )

        PortfolioTransaction.create!(
          portfolio: portfolio,
          transaction_type: 'reserve',
          amount: amount,
          currency: portfolio.currency,
          status: 'completed',
          idempotency_key: "reserve-#{order_id}",
          processed_at: Time.current
        )
      end

      render json: {
        success: true,
        client_id: client_id,
        reserved_amount: amount,
        order_id: order_id,
        new_available_balance: portfolio.reload.available_balance
      }
    rescue ActiveRecord::RecordInvalid => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # POST /internal/release
    # Release reserved funds (compensation on order failure/cancellation)
    def release
      client_id = params[:client_id]
      amount = params[:amount].to_f
      order_id = params[:order_id]

      portfolio = Portfolio.find_by(client_id: client_id)

      unless portfolio
        render json: { success: false, error: 'Portfolio not found' }, status: :not_found
        return
      end

      # Release the reserved funds
      ActiveRecord::Base.transaction do
        new_reserved = [portfolio.reserved_amount - amount, 0].max
        portfolio.update!(reserved_amount: new_reserved)

        PortfolioTransaction.create!(
          portfolio: portfolio,
          transaction_type: 'release',
          amount: amount,
          currency: portfolio.currency,
          status: 'completed',
          idempotency_key: "release-#{order_id}",
          processed_at: Time.current
        )
      end

      render json: {
        success: true,
        client_id: client_id,
        released_amount: amount,
        order_id: order_id,
        new_available_balance: portfolio.reload.available_balance
      }
    rescue ActiveRecord::RecordInvalid => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # POST /internal/debit
    # Debit funds after order execution
    def debit
      client_id = params[:client_id]
      amount = params[:amount].to_f
      order_id = params[:order_id]

      portfolio = Portfolio.find_by(client_id: client_id)

      unless portfolio
        render json: { success: false, error: 'Portfolio not found' }, status: :not_found
        return
      end

      # Debit from reserved amount and balance
      ActiveRecord::Base.transaction do
        new_reserved = [portfolio.reserved_amount - amount, 0].max
        new_balance = portfolio.cash_balance - amount

        portfolio.update!(
          reserved_amount: new_reserved,
          cash_balance: new_balance
        )

        PortfolioTransaction.create!(
          portfolio: portfolio,
          transaction_type: 'debit',
          amount: amount,
          currency: portfolio.currency,
          status: 'completed',
          idempotency_key: "debit-#{order_id}",
          processed_at: Time.current
        )
      end

      render json: {
        success: true,
        client_id: client_id,
        debited_amount: amount,
        order_id: order_id,
        new_balance: portfolio.reload.cash_balance
      }
    rescue ActiveRecord::RecordInvalid => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # GET /internal/balance/:client_id
    # Check available balance for a client
    def balance
      client_id = params[:client_id]
      portfolio = Portfolio.find_by(client_id: client_id)

      unless portfolio
        render json: { success: false, error: 'Portfolio not found' }, status: :not_found
        return
      end

      render json: {
        success: true,
        client_id: client_id,
        balance: portfolio.cash_balance,
        reserved_amount: portfolio.reserved_amount,
        available_balance: portfolio.available_balance
      }
    end

    private

    def authenticate_internal_request!
      internal_token = request.headers['X-Internal-Token']
      expected_token = ENV.fetch('INTERNAL_SERVICE_TOKEN', 'internal_service_secret')

      unless internal_token == expected_token
        render json: { success: false, error: 'Unauthorized internal request' }, status: :unauthorized
      end
    end
  end
end
