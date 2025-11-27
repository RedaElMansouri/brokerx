# frozen_string_literal: true

# UC-03: Dépôt de fonds idempotent
# Allows authenticated clients to deposit funds into their portfolio
# Uses Idempotency-Key to prevent duplicate transactions
class DepositFundsUseCase
  def execute(client_id:, amount:, currency:, idempotency_key:, portfolio_id: nil)
    # Validate amount
    return error_result('Amount must be positive', 'invalid_amount') if amount <= 0

    # Find portfolio
    portfolio = find_portfolio(client_id, portfolio_id)
    return error_result('Portfolio not found', 'portfolio_not_found') unless portfolio

    # Check for existing transaction with same idempotency key (idempotency check)
    existing_transaction = PortfolioTransaction.find_by(
      portfolio_id: portfolio.id,
      idempotency_key: idempotency_key
    )

    if existing_transaction
      # Return existing transaction (idempotent response)
      Rails.logger.info("Idempotent deposit detected: #{idempotency_key}")
      return success_result(
        existing_transaction,
        'Deposit already processed (idempotent response)',
        already_processed: true
      )
    end

    # Process deposit
    result = portfolio.deposit!(amount, idempotency_key: idempotency_key, currency: currency)

    if result[:success]
      # Publish event for outbox pattern
      publish_deposit_event(portfolio, result[:transaction])

      success_result(
        result[:transaction],
        'Deposit completed successfully',
        already_processed: result[:already_processed]
      )
    else
      error_result('Deposit failed', 'processing_error')
    end
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition - another request with same idempotency key was processed
    existing = PortfolioTransaction.find_by(idempotency_key: idempotency_key)
    if existing
      success_result(existing, 'Deposit already processed (concurrent request)', already_processed: true)
    else
      error_result('Duplicate key conflict', 'duplicate_key_conflict')
    end
  rescue ArgumentError => e
    error_result(e.message, 'invalid_amount')
  rescue StandardError => e
    Rails.logger.error("Deposit failed: #{e.message}")
    error_result(e.message, 'processing_error')
  end

  private

  def find_portfolio(client_id, portfolio_id)
    if portfolio_id
      Portfolio.find_by(id: portfolio_id, client_id: client_id)
    else
      # Get default portfolio for client, or create one if none exists
      portfolio = Portfolio.find_by(client_id: client_id)
      portfolio ||= Portfolio.create!(
        client_id: client_id,
        name: 'Default Portfolio',
        currency: 'CAD'
      )
      portfolio
    end
  end

  def publish_deposit_event(portfolio, transaction)
    OutboxEvent.create!(
      aggregate_type: 'Portfolio',
      aggregate_id: portfolio.id,
      event_type: 'FundsDeposited',
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
    # Log but don't fail the deposit if event publishing fails
    Rails.logger.warn("Failed to publish deposit event: #{e.message}")
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
