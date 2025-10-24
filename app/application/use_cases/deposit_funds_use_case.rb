module Application
  module UseCases
    class DepositFundsUseCase
      MIN_AMOUNT = 1.0
      MAX_AMOUNT = 100_000.0

      def initialize(portfolio_repository)
        @portfolio_repository = portfolio_repository
      end

      # Execute a simulated deposit
      # params: account_id:, amount:, currency:, idempotency_key: (optional)
      def execute(params)
        account_id = params.fetch(:account_id)
        amount = params.fetch(:amount).to_f
        currency = (params[:currency] || 'USD').to_s.upcase
        idempo = params[:idempotency_key]

        raise ArgumentError, 'Invalid amount' unless amount.positive?
        raise ArgumentError, "Amount below minimum (#{MIN_AMOUNT})" if amount < MIN_AMOUNT
        raise ArgumentError, "Amount above maximum (#{MAX_AMOUNT})" if amount > MAX_AMOUNT

        ActiveRecord::Base.transaction do
          # Idempotency check
          if idempo
            existing = ::Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.find_by(
              account_id: account_id, idempotency_key: idempo
            )
            return { status: existing.status, transaction_id: existing.id } if existing
          end

          # Create pending transaction
          tx = ::Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.create!(
            account_id: account_id,
            operation_type: 'deposit',
            amount: amount,
            currency: currency,
            status: 'pending',
            idempotency_key: idempo,
            metadata: {}
          )

          # Simulated payment settles immediately (synchronous happy path)
          tx.update!(status: 'settled', settled_at: Time.current)

          # Credit portfolio balances using domain entity behavior
          portfolio = @portfolio_repository.find_by_account_id(account_id)
          raise 'Portfolio not found' unless portfolio

          portfolio.credit(amount)
          @portfolio_repository.save(portfolio)

          { status: 'settled', transaction_id: tx.id }
        end
      end
    end
  end
end
