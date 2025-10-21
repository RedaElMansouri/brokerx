module UseCases
  class AuthenticateUserUseCase
      def initialize(client_repository)
        @client_repository = client_repository
      end

      def execute(email, password)
        # Validate credentials and state
        client = @client_repository.find_by_email(email)
        raise "Invalid credentials" unless client
        raise "Account not active" unless client.active?

        # Check password with bcrypt using AR record (avoid exposing digest in domain)
  ar = ::Infrastructure::Persistence::ActiveRecord::ClientRecord.find(client.id)
        unless ar.authenticate(password)
          raise "Invalid credentials"
        end

        {
          client: client,
          token: generate_jwt_token(client.id)
        }
      end

      private

      def generate_jwt_token(client_id)
        payload = {
          client_id: client_id,
          iss: 'brokerx',
          aud: 'brokerx.web',
          iat: Time.now.to_i,
          exp: 24.hours.from_now.to_i
        }
        JWT.encode(payload, Rails.application.secret_key_base)
      end
  end
end
