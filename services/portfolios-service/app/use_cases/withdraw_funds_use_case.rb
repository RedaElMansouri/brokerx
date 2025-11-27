# frozen_string_literal: true

# Withdraw funds from portfolio with idempotency
class WithdrawFundsUseCase
  def execute(client_id:, amount:, currency:, idempotency_key:, portfolio_id: nil)
    # Validate amount
    return error_result('Amount must be positive', 'invalid_amount') if amount <= 0

    # Find portfolio
    portfolio = find_portfolio(client_id, portfolio_id)
    return error_result('Portfolio not found', 'portfolio_not_found') unless portfolio

    # Check for existing transaction with same idempotency key
    existing_transaction = PortfolioTransaction.find_by(
      portfolio_id: portfolio.id,
      idempotency_key: idempotency_key
    )

    if existing_transaction
      Rails.logger.info("Idempotent withdrawal detected: #{idempotency_key}")
      return success_result(
        existing_transaction,
        'Withdrawal already processed (idempotent response)',
        already_processed: true
      )
    end

    # Check sufficient funds
    if portfolio.cash_balance < amount
      return error_result(
        "Insufficient funds. Available: #{portfolio.cash_balance}, Requested: #{amount}",
        'insufficient_funds'
      )
    end

    # Process withdrawal
    result = portfolio.withdraw!(amount, idempotency_key: idempotency_key, currency: currency)

    if result[:success]
      publish_withdrawal_event(portfolio, result[:transaction])

      success_result(
        result[:transaction],
        'Withdrawal completed successfully',
        already_processed: result[:already_processed]
      )
    else
      error_result('Withdrawal failed', 'processing_error')
    end
  rescue ActiveRecord::RecordNotUnique
    existing = PortfolioTransaction.find_by(idempotency_key: idempotency_key)
    if existing
      success_result(existing, 'Withdrawal already processed (concurrent request)', already_processed: true)
    else
      error_result('Duplicate key conflict', 'duplicate_key_conflict')
    end
  rescue ArgumentError => e
    error_result(e.message, e.message.include?('Insufficient') ? 'insufficient_funds' : 'invalid_amount')
  rescue StandardError => e
    Rails.logger.error("Withdrawal failed: #{e.message}")
    error_result(e.message, 'processing_error')
  end

  private

  def find_portfolio(client_id, portfolio_id)
    if portfolio_id
      Portfolio.find_by(id: portfolio_id, client_id: client_id)
    else
      Portfolio.find_by(client_id: client_id)
    end
  end

  def publish_withdrawal_event(portfolio, transaction)
    OutboxEvent.create!(
      aggregate_type: 'Portfolio',
      aggregate_id: portfolio.id,
      event_type: 'FundsWithdrawn',
      payload: {
        portfolio_id: portfolio.id,
        client_id: portfolio.client_id,
        transaction_id: transaction.id,
        amount: transaction.amount.to_f,
        currency: transaction.currency,
        new_balance: portfolio.cash_balance.to_f,
        idempotency_key: transaction.idempotency_key,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to publish withdrawal event: #{e.message}")
  end

  def success_result(transaction, message, already_processed: false)
    {
      success: true,
      transaction: transaction,
      message: message,
      already_processed: already_processed
    }
  end

  def error_result(message, code)
    {
      success: false,
      error: message,
      code: code
    }
  end
end
