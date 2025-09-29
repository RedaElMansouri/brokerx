module Api
  module V1
    class ClientsController < ApplicationController
      def create
        # Ensure domain/application/infrastructure constants are loaded
        load_dependencies

        # Ensure we pass keyword args to the DTO (it requires keywords)
        dto_attrs = client_params.to_h.symbolize_keys
        if dto_attrs[:date_of_birth].is_a?(String)
          begin
            dto_attrs[:date_of_birth] = Date.parse(dto_attrs[:date_of_birth])
          rescue ArgumentError
            return render json: { success: false, error: 'Invalid date_of_birth format' }, status: :unprocessable_entity
          end
        end

        dto = Application::Dtos::ClientRegistrationDto.new(**dto_attrs)
        use_case = Application::UseCases::RegisterClientUseCase.new(
          client_repository,
          portfolio_repository
        )

        result = use_case.execute(dto)

        # Send verification link / token by email (or log in development)
        verification_token = result[:verification_token]
        client_email = result[:client].email.value
        if Rails.env.development?
          Rails.logger.info("[DEV VERIFICATION] token for #{client_email}: #{verification_token}")
        else
          # Use ApplicationMailer or specific mailer to send verification
          if defined?(VerificationMailer)
            VerificationMailer.with(email: client_email, token: verification_token).send_verification.deliver_later
          end
        end

        render json: {
          success: true,
          client: {
            id: result[:client].id,
            email: result[:client].email.value,
            full_name: result[:client].full_name,
            status: result[:client].status
          },
          message: "Registration successful. A verification token has been sent to your email."
        }, status: :created

      rescue => e
        logger.error "Registration error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end

      def verify
        load_dependencies

        client = client_repository.find_by_verification_token(params[:token])
        raise "Invalid verification token" unless client

        client.activate!(params[:token])
        client_repository.save(client)

        render json: {
          success: true,
          message: "Account activated successfully"
        }

      rescue => e
        logger.error "Verification error: #{e.message}"
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end

      private

      def load_dependencies
        # Load domain files
        load 'app/domain/shared/value_object.rb' if File.exist?(Rails.root.join('app','domain','shared','value_object.rb'))
        load 'app/domain/shared/entity.rb' if File.exist?(Rails.root.join('app','domain','shared','entity.rb'))
        load 'app/domain/shared/repository.rb' if File.exist?(Rails.root.join('app','domain','shared','repository.rb'))
        load 'app/domain/clients/value_objects/email.rb' if File.exist?(Rails.root.join('app','domain','clients','value_objects','email.rb'))
        load 'app/domain/clients/value_objects/money.rb' if File.exist?(Rails.root.join('app','domain','clients','value_objects','money.rb'))
        load 'app/domain/clients/entities/client.rb' if File.exist?(Rails.root.join('app','domain','clients','entities','client.rb'))
        load 'app/domain/clients/entities/portfolio.rb' if File.exist?(Rails.root.join('app','domain','clients','entities','portfolio.rb'))
        load 'app/domain/clients/repositories/client_repository.rb' if File.exist?(Rails.root.join('app','domain','clients','repositories','client_repository.rb'))
        load 'app/domain/clients/repositories/portfolio_repository.rb' if File.exist?(Rails.root.join('app','domain','clients','repositories','portfolio_repository.rb'))

        # Application
        load 'app/application/dtos/client_registration_dto.rb' if File.exist?(Rails.root.join('app','application','dtos','client_registration_dto.rb'))
        load 'app/application/use_cases/register_client_use_case.rb' if File.exist?(Rails.root.join('app','application','use_cases','register_client_use_case.rb'))

        # Infrastructure
        load 'app/models/client_record.rb' if File.exist?(Rails.root.join('app','models','client_record.rb'))
  load 'app/infrastructure/persistence/active_record/portfolio_record.rb' if File.exist?(Rails.root.join('app','infrastructure','persistence','active_record','portfolio_record.rb'))
  load 'app/models/portfolio_record.rb' if File.exist?(Rails.root.join('app','models','portfolio_record.rb'))
  load 'app/infrastructure/persistence/repositories/active_record_client_repository.rb' if File.exist?(Rails.root.join('app','infrastructure','persistence','repositories','active_record_client_repository.rb'))
  load 'app/infrastructure/persistence/repositories/active_record_portfolio_repository.rb' if File.exist?(Rails.root.join('app','infrastructure','persistence','repositories','active_record_portfolio_repository.rb'))
      end

      def client_params
        params.require(:client).permit(:email, :first_name, :last_name, :date_of_birth, :phone, :password)
      end

      def client_repository
        @client_repository ||= Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
      end

      def portfolio_repository
        @portfolio_repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
      end
    end
  end
end
