# frozen_string_literal: true

# @deprecated This controller is deprecated and will be removed in a future version.
# Client registration and verification is now handled by the clients-service microservice.
# This code is kept as a fallback only. Use Kong Gateway (port 8080) for production traffic.
# See: docs/architecture/microservices-architecture.md
module Api
  module V1
    class ClientsController < ApplicationController
      # @deprecated Use clients-service via Kong Gateway instead
      def create
        # Inscription d'un client (crée un portefeuille associé)
        Rails.logger.warn("[DEPRECATED] ClientsController#create called - use clients-service instead")

        # Garantir des mots-clés pour le DTO
        dto_attrs = client_params.to_h.symbolize_keys
        if dto_attrs[:date_of_birth].is_a?(String)
          begin
            dto_attrs[:date_of_birth] = Date.parse(dto_attrs[:date_of_birth])
          rescue ArgumentError
            return render_api_error(code: 'validation_failed', message: 'Invalid date_of_birth format', status: :unprocessable_entity)
          end
        end

        dto = Application::Dtos::ClientRegistrationDto.new(**dto_attrs)
        use_case = Application::UseCases::RegisterClientUseCase.new(
          client_repository,
          portfolio_repository
        )

        result = use_case.execute(dto)

        # Envoi du lien/token de vérification par email (ou journalisation en dev)
        verification_token = result[:verification_token]
        client_email = result[:client].email.value
        if Rails.env.development?
          Rails.logger.info("[DEV VERIFICATION] token for #{client_email}: #{verification_token}")
        elsif defined?(VerificationMailer)
          # Utiliser un mailer pour expédier la vérification
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
        render_api_error(code: 'internal_error', message: e.message, status: :unprocessable_entity)
      end

      def verify
        # Activation de compte via token de vérification

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
        render_api_error(code: 'validation_failed', message: e.message, status: :unprocessable_entity)
      end

      private

      # Paramètres forts

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
