# frozen_string_literal: true

# Create a new portfolio for a client
class CreatePortfolioUseCase
  def execute(client_id:, name:, currency: 'CAD')
    # Validate inputs
    return error_result('Client ID is required') unless client_id.present?
    return error_result('Portfolio name is required') unless name.present?
    return error_result('Invalid currency') unless %w[CAD USD EUR].include?(currency)

    # Create portfolio
    portfolio = Portfolio.create!(
      client_id: client_id,
      name: name,
      currency: currency,
      cash_balance: 0.0,
      status: 'active'
    )

    # Publish event
    publish_portfolio_created_event(portfolio)

    {
      success: true,
      portfolio: portfolio,
      message: 'Portfolio created successfully'
    }
  rescue ActiveRecord::RecordInvalid => e
    error_result(e.message)
  rescue StandardError => e
    Rails.logger.error("Failed to create portfolio: #{e.message}")
    error_result(e.message)
  end

  private

  def publish_portfolio_created_event(portfolio)
    OutboxEvent.create!(
      aggregate_type: 'Portfolio',
      aggregate_id: portfolio.id,
      event_type: 'PortfolioCreated',
      payload: {
        portfolio_id: portfolio.id,
        client_id: portfolio.client_id,
        name: portfolio.name,
        currency: portfolio.currency,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to publish portfolio created event: #{e.message}")
  end

  def error_result(message)
    {
      success: false,
      error: message
    }
  end
end
