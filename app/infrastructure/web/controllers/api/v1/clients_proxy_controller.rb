# frozen_string_literal: true

module Api
  module V1
    # Strangler Fig Pattern - Proxy Controller for Clients
    # Delegates to clients-service microservice when enabled
    # Falls back to local code when microservice is disabled
    class ClientsProxyController < ApplicationController
      # Note: No authentication required for registration and verification endpoints

      # POST /api/v1/clients/register
      def register
        if StranglerFig.use_microservice?(:clients)
          delegate_to_microservice(:register)
        else
          delegate_to_local(:create)
        end
      end

      # GET /api/v1/clients/verify_email
      def verify_email
        if StranglerFig.use_microservice?(:clients)
          delegate_to_microservice(:verify_email)
        else
          delegate_to_local(:verify)
        end
      end

      # GET /api/v1/clients/profile
      def profile
        if StranglerFig.use_microservice?(:clients)
          delegate_to_microservice(:get_profile)
        else
          delegate_to_local(:show)
        end
      end

      private

      def delegate_to_microservice(action)
        facade = ClientsFacade.new

        result = case action
                 when :register
                   facade.register(
                     email: params[:email],
                     password: params[:password],
                     name: "#{params[:first_name]} #{params[:last_name]}"
                   )
                 when :verify_email
                   facade.verify_email(token: params[:token])
                 when :get_profile
                   facade.get_profile(jwt_token: request.headers['Authorization']&.split(' ')&.last)
                 end

        if result[:success]
          render json: result[:data], status: result[:status] || :ok
        else
          render json: result[:error], status: result[:status] || :unprocessable_entity
        end
      rescue BaseFacade::ServiceUnavailableError => e
        Rails.logger.warn("[StranglerFig] Microservice unavailable, falling back to local: #{e.message}")
        delegate_to_local(fallback_action(action))
      end

      def delegate_to_local(action)
        # Redirect to the original controller
        controller = Api::V1::ClientsController.new
        controller.request = request
        controller.response = response
        controller.send(action)
      end

      def fallback_action(microservice_action)
        case microservice_action
        when :register then :create
        when :verify_email then :verify
        when :get_profile then :show
        else microservice_action
        end
      end
    end
  end
end
