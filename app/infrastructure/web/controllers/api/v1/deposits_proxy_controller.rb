# frozen_string_literal: true

module Api
  module V1
    # Strangler Fig Pattern - Proxy Controller for Deposits & Portfolios
    # Delegates to portfolios-service microservice when enabled
    class DepositsProxyController < ApplicationController
      # POST /api/v1/deposits
      def create
        if StranglerFig.use_microservice?(:portfolios)
          delegate_to_microservice(:deposit)
        else
          delegate_to_local(:create)
        end
      end

      # GET /api/v1/deposits
      def index
        if StranglerFig.use_microservice?(:portfolios)
          delegate_to_microservice(:get_deposits)
        else
          delegate_to_local(:index)
        end
      end

      # GET /api/v1/portfolio
      def portfolio
        if StranglerFig.use_microservice?(:portfolios)
          delegate_to_microservice(:get_portfolio)
        else
          delegate_to_local_portfolio
        end
      end

      private

      def delegate_to_microservice(action)
        facade = PortfoliosFacade.new
        jwt_token = request.headers['Authorization']&.split(' ')&.last
        idempotency_key = request.headers['Idempotency-Key']

        result = case action
                 when :deposit
                   facade.deposit(
                     jwt_token: jwt_token,
                     amount: params[:amount],
                     currency: params[:currency] || 'USD',
                     idempotency_key: idempotency_key
                   )
                 when :get_deposits
                   facade.get_deposits(jwt_token: jwt_token)
                 when :get_portfolio
                   facade.get_portfolio(jwt_token: jwt_token)
                 end

        if result[:success]
          render json: result[:data], status: result[:status] || :ok
        else
          render json: result[:error], status: result[:status] || :unprocessable_entity
        end
      rescue BaseFacade::ServiceUnavailableError => e
        Rails.logger.warn("[StranglerFig] Microservice unavailable, falling back to local: #{e.message}")
        fallback_action = case action
                          when :deposit then :create
                          when :get_deposits then :index
                          when :get_portfolio then :show
                          end
        action == :get_portfolio ? delegate_to_local_portfolio : delegate_to_local(fallback_action)
      end

      def delegate_to_local(action)
        controller = Api::V1::DepositsController.new
        controller.request = request
        controller.response = response
        controller.send(action)
      end

      def delegate_to_local_portfolio
        controller = Api::V1::PortfoliosController.new
        controller.request = request
        controller.response = response
        controller.send(:show)
      end
    end
  end
end
