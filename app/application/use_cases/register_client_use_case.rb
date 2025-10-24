module Application
  module UseCases
    class RegisterClientUseCase
      def initialize(client_repository, portfolio_repository)
        @client_repository = client_repository
        @portfolio_repository = portfolio_repository
      end

      def execute(dto)
        # Vérifier si l'email existe déjà
        existing_client = @client_repository.find_by_email(dto.email)
        raise 'Email already exists' if existing_client

        # Créer le client
        client = Domain::Clients::Entities::Client.new(
          email: dto.email,
          first_name: dto.first_name,
          last_name: dto.last_name,
          date_of_birth: dto.date_of_birth,
          verification_token: generate_verification_token
        )

        # Sauvegarder le client
        saved_client = @client_repository.save(client)

        # Définir le mot de passe si fourni (via ActiveRecord, pour has_secure_password)
        if dto.password && !dto.password.to_s.strip.empty?
          ar = ::Infrastructure::Persistence::ActiveRecord::ClientRecord.find(saved_client.id)
          ar.password = dto.password
          ar.save!
        end

        # Créer un portfolio pour le client
        portfolio = Domain::Clients::Entities::Portfolio.new(
          account_id: saved_client.id,
          currency: 'USD',
          available_balance: 0,
          reserved_balance: 0
        )

        @portfolio_repository.save(portfolio)

        # Ici, normalement on enverrait un email de vérification
        # Pour le prototype, on retourne juste le client

        {
          client: saved_client,
          verification_token: client.verification_token
        }
      end

      private

      def generate_verification_token
        SecureRandom.hex(20)
      end
    end
  end
end
