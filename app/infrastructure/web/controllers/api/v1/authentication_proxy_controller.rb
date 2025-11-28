# frozen_string_literal: true

module Api
  module V1
    # Strangler Fig Pattern - Proxy Controller for Authentication
    # Delegates to clients-service microservice when enabled
    class AuthenticationProxyController < ApplicationController
      # Note: No authentication required for login and MFA verification endpoints

      # POST /api/v1/auth/login
      def login
        if StranglerFig.use_microservice?(:clients)
          delegate_to_microservice(:login)
        else
          delegate_to_local(:login)
        end
      end

      # POST /api/v1/auth/verify_mfa
      def verify_mfa
        if StranglerFig.use_microservice?(:clients)
          delegate_to_microservice(:verify_mfa)
        else
          delegate_to_local(:verify_mfa)
        end
      end

      private

      def delegate_to_microservice(action)
        facade = ClientsFacade.new

        result = case action
                 when :login
                   facade.login(
                     email: params[:email],
                     password: params[:password]
                   )
                 when :verify_mfa
                   facade.verify_mfa(
                     session_token: params[:session_token],
                     mfa_code: params[:mfa_code]
                   )
                 end

        if result[:success]
          render json: result[:data], status: result[:status] || :ok
        else
          render json: result[:error], status: result[:status] || :unauthorized
        end
      rescue BaseFacade::ServiceUnavailableError => e
        Rails.logger.warn("[StranglerFig] Microservice unavailable, falling back to local: #{e.message}")
        delegate_to_local(action)
      end

      def delegate_to_local(action)
        controller = Api::V1::AuthenticationController.new
        controller.request = request
        controller.response = response
        controller.send(action)
      end
    end
  end
end
