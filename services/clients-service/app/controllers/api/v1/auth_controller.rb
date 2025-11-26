# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_client!, only: [:logout]

      # POST /api/v1/auth/login - UC-02: Première étape authentification
      def login
        result = LoginUseCase.new.execute(
          email: params[:email],
          password: params[:password]
        )

        if result.success?
          render json: {
            message: 'MFA code sent to your email',
            mfa_required: true,
            session_token: result.session_token
          }
        else
          render json: {
            error: 'Authentication failed',
            code: 'AUTH_FAILED',
            details: result.errors
          }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/verify_mfa - UC-02: Vérification MFA
      def verify_mfa
        result = VerifyMfaUseCase.new.execute(
          session_token: params[:session_token],
          mfa_code: params[:mfa_code]
        )

        if result.success?
          render json: {
            message: 'Authentication successful',
            token: result.jwt_token,
            client: ClientSerializer.new(result.client).as_json,
            expires_at: result.expires_at.iso8601
          }
        else
          render json: {
            error: 'MFA verification failed',
            code: 'MFA_FAILED',
            details: result.errors
          }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/logout
      def logout
        result = LogoutUseCase.new.execute(client: current_client)

        if result.success?
          render json: { message: 'Logged out successfully' }
        else
          render json: { error: 'Logout failed' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/refresh_token
      def refresh_token
        result = RefreshTokenUseCase.new.execute(
          refresh_token: params[:refresh_token]
        )

        if result.success?
          render json: {
            token: result.jwt_token,
            expires_at: result.expires_at.iso8601
          }
        else
          render json: {
            error: 'Token refresh failed',
            code: 'REFRESH_FAILED'
          }, status: :unauthorized
        end
      end
    end
  end
end
