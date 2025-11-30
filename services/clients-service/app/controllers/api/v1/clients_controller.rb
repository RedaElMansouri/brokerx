# frozen_string_literal: true

module Api
  module V1
    class ClientsController < ApplicationController
      # POST /api/v1/clients - UC-01: Inscription
      def create
        result = RegisterClientUseCase.new.execute(client_params)

        if result.success?
          response_data = {
            message: 'Client registered successfully. Please check your email for verification.',
            client: ClientSerializer.new(result.client).as_json
          }
          
          # Include verification token in development/test for easier testing
          if Rails.env.development? || Rails.env.test?
            verification_token = result.client.verification_tokens.last
            response_data[:verification_token] = verification_token&.token
          end
          
          render json: response_data, status: :created
        else
          render json: {
            error: 'Registration failed',
            code: 'REGISTRATION_FAILED',
            details: result.errors
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/clients/:id
      def show
        authenticate_client!
        
        client = Client.find(params[:id])
        
        # Clients can only view their own profile
        unless client.id == current_client.id
          return render json: { error: 'Forbidden' }, status: :forbidden
        end

        render json: ClientSerializer.new(client).as_json
      end

      # POST /api/v1/clients/:id/verify_email - UC-01: Vérification
      def verify_email
        result = VerifyEmailUseCase.new.execute(
          client_id: params[:id],
          token: params[:token]
        )

        if result.success?
          render json: {
            message: 'Email verified successfully',
            client: ClientSerializer.new(result.client).as_json
          }
        else
          render json: {
            error: 'Verification failed',
            code: 'VERIFICATION_FAILED',
            details: result.errors
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/clients/:id/resend_verification
      def resend_verification
        result = ResendVerificationUseCase.new.execute(client_id: params[:id])

        if result.success?
          render json: { message: 'Verification email sent' }
        else
          render json: {
            error: 'Failed to resend verification',
            code: 'RESEND_FAILED',
            details: result.errors
          }, status: :unprocessable_entity
        end
      end

      private

      def client_params
        params.require(:client).permit(:email, :password, :password_confirmation, :name)
      end
    end
  end
end
