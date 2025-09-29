module Domain
  module Clients
    module Repositories
      class PortfolioRepository < Domain::Shared::Repository::BaseRepository
        def find_by_account_id(account_id)
          raise NotImplementedError
        end

        def update_balance(portfolio_id, available_balance, reserved_balance)
          raise NotImplementedError
        end

        def reserve_funds(portfolio_id, amount)
          raise NotImplementedError
        end

        def release_funds(portfolio_id, amount)
          raise NotImplementedError
        end
      end
    end
  end
end
