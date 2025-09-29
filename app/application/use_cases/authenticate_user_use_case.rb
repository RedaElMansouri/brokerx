module Application
  module UseCases
    class AuthenticateUserUseCase
      def initialize(client_repository)
        @client_repository = client_repository
      end

      def execute(email, password)
        # Pour le prototype, on valide juste que le client existe et est actif
        # En production, on utiliserait bcrypt pour les mots de passe

        client = @client_repository.find_by_email(email)
        raise "Invalid credentials" unless client
        raise "Account not active" unless client.active?

        # Ici, normalement on vérifierait le mot de passe avec bcrypt
        # Pour le prototype, on suppose que l'authentification réussit

        {
          client: client,
          token: generate_jwt_token(client.id)
        }
      end

      private

      def generate_jwt_token(client_id)
        payload = {
          client_id: client_id,
          exp: 24.hours.from_now.to_i
        }
        JWT.encode(payload, Rails.application.secret_key_base)
      end
    end
  end
end
