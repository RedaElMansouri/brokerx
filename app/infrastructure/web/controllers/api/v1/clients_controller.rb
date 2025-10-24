module Api
  module V1
    class ClientsController < ApplicationController
      def create
        # Rely on Rails autoloading; domain is eager-loaded via initializer

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
        elsif defined?(VerificationMailer)
          # Use ApplicationMailer or specific mailer to send verification
          VerificationMailer.with(email: client_email, token: verification_token).send_verification.deliver_later
        end

        render json: {
          success: true,
          client: {
            id: result[:client].id,
            email: result[:client].email.value,
            full_name: result[:client].full_name,
            status: result[:client].status
          },
          message: 'Registration successful. A verification token has been sent to your email.'
        }, status: :created
      rescue StandardError => e
        logger.error "Registration error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end

      def verify
        # Rely on Rails autoloading; domain is eager-loaded via initializer

        client = client_repository.find_by_verification_token(params[:token])
        raise 'Invalid verification token' unless client

        client.activate!(params[:token])
        client_repository.save(client)

        render json: {
          success: true,
          message: 'Account activated successfully'
        }
      rescue StandardError => e
        logger.error "Verification error: #{e.message}"
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end

      private

      # No more manual load_dependencies

      def client_params
        params.require(:client).permit(:email, :first_name, :last_name, :date_of_birth, :phone, :password)
      end

      def client_repository
        @client_repository ||= ::Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
      end

      def portfolio_repository
        @portfolio_repository ||= ::Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
      end
    end
  end
end
