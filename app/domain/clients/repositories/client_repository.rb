module Domain
  module Clients
    module Repositories
      class ClientRepository < Domain::Shared::Repository::BaseRepository
        def find_by_email(email)
          raise NotImplementedError
        end

        def find_by_verification_token(token)
          raise NotImplementedError
        end

        def find_active_clients
          raise NotImplementedError
        end
      end
    end
  end
end
