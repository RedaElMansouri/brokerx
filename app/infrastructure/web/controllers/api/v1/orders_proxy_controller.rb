# frozen_string_literal: true

module Api
  module V1
    # Strangler Fig Pattern - Proxy Controller for Orders
    # Delegates to orders-service microservice when enabled
    class OrdersProxyController < ApplicationController
      # POST /api/v1/orders
      def create
        if StranglerFig.use_microservice?(:orders)
          delegate_to_microservice(:place_order)
        else
          delegate_to_local(:create)
        end
      end

      # GET /api/v1/orders
      def index
        if StranglerFig.use_microservice?(:orders)
          delegate_to_microservice(:get_orders)
        else
          delegate_to_local(:index)
        end
      end

      # GET /api/v1/orders/:id
      def show
        if StranglerFig.use_microservice?(:orders)
          delegate_to_microservice(:get_order)
        else
          delegate_to_local(:show)
        end
      end

      # POST /api/v1/orders/:id/replace
      def replace
        if StranglerFig.use_microservice?(:orders)
          delegate_to_microservice(:modify_order)
        else
          delegate_to_local(:replace)
        end
      end

      # POST /api/v1/orders/:id/cancel
      def cancel
        if StranglerFig.use_microservice?(:orders)
          delegate_to_microservice(:cancel_order)
        else
          delegate_to_local(:cancel)
        end
      end

      private

      def delegate_to_microservice(action)
        facade = OrdersFacade.new
        jwt_token = request.headers['Authorization']&.split(' ')&.last
        idempotency_key = request.headers['Idempotency-Key']

        result = case action
                 when :place_order
                   facade.place_order(
                     jwt_token: jwt_token,
                     symbol: params[:symbol],
                     direction: params[:direction],
                     order_type: params[:order_type],
                     quantity: params[:quantity],
                     price: params[:price],
                     time_in_force: params[:time_in_force] || 'DAY',
                     idempotency_key: idempotency_key
                   )
                 when :get_orders
                   facade.get_orders(jwt_token: jwt_token, limit: params[:limit] || 50)
                 when :get_order
                   facade.get_order(jwt_token: jwt_token, order_id: params[:id])
                 when :modify_order
                   facade.modify_order(
                     jwt_token: jwt_token,
                     order_id: params[:id],
                     price: params.dig(:order, :price),
                     quantity: params.dig(:order, :quantity),
                     client_version: params.dig(:order, :client_version)
                   )
                 when :cancel_order
                   facade.cancel_order(jwt_token: jwt_token, order_id: params[:id])
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
        controller = Api::V1::OrdersController.new
        controller.request = request
        controller.response = response
        controller.send(action)
      end

      def fallback_action(microservice_action)
        case microservice_action
        when :place_order then :create
        when :get_orders then :index
        when :get_order then :show
        when :modify_order then :replace
        when :cancel_order then :cancel
        else microservice_action
        end
      end
    end
  end
end
