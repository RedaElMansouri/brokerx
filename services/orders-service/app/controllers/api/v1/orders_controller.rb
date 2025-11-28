# frozen_string_literal: true

module Api
  module V1
    # UC-05: Place Order
    # UC-06: Modify/Cancel Order
    class OrdersController < ApplicationController
      # GET /api/v1/orders
      def index
        orders = Order.where(client_id: current_client_id)
                      .order(created_at: :desc)
                      .limit(params[:limit] || 50)

        render json: {
          success: true,
          data: orders.map { |o| order_json(o) },
          meta: { count: orders.count }
        }
      end

      # GET /api/v1/orders/:id
      def show
        order = find_order

        render json: {
          success: true,
          **order_json(order)
        }
      end

      # POST /api/v1/orders (UC-05)
      def create
        idempotency_key = request.headers['Idempotency-Key']

        # Check for existing order with same idempotency key
        if idempotency_key.present?
          existing_order = Order.find_by(client_id: current_client_id, idempotency_key: idempotency_key)
          if existing_order
            render json: {
              success: true,
              **order_json(existing_order),
              correlation_id: existing_order.correlation_id,
              message: 'Order already exists (idempotent response)'
            }, status: :ok
            return
          end
        end

        use_case = PlaceOrderUseCase.new
        result = use_case.execute(
          client_id: current_client_id,
          symbol: params[:symbol],
          direction: params[:direction],
          order_type: params[:order_type],
          quantity: params[:quantity].to_i,
          price: params[:price]&.to_f,
          time_in_force: params[:time_in_force] || 'DAY',
          correlation_id: correlation_id,
          idempotency_key: idempotency_key
        )

        if result[:success]
          render json: {
            success: true,
            **order_json(result[:order]),
            correlation_id: correlation_id,
            message: 'Order placed successfully'
          }, status: :created
        else
          render json: {
            success: false,
            errors: [result[:error]],
            code: result[:code]
          }, status: error_status(result[:code])
        end
      end

      # POST /api/v1/orders/:id/replace (UC-06)
      def replace
        order = find_order
        
        use_case = ModifyOrderUseCase.new
        result = use_case.execute(
          order: order,
          client_version: params.dig(:order, :client_version),
          price: params.dig(:order, :price)&.to_f,
          quantity: params.dig(:order, :quantity)&.to_i,
          time_in_force: params.dig(:order, :time_in_force)
        )

        if result[:success]
          render json: {
            success: true,
            **order_json(result[:order]),
            message: 'Order modified'
          }
        else
          status = result[:code] == 'version_conflict' ? :conflict : :unprocessable_entity
          render json: {
            success: false,
            code: result[:code],
            message: result[:error]
          }, status: status
        end
      end

      # POST /api/v1/orders/:id/cancel (UC-06)
      def cancel
        order = find_order
        
        use_case = CancelOrderUseCase.new
        result = use_case.execute(
          order: order,
          client_version: params[:client_version]
        )

        if result[:success]
          render json: {
            success: true,
            status: 'cancelled',
            lock_version: result[:order].lock_version,
            message: 'Order cancelled'
          }
        else
          status = result[:code] == 'version_conflict' ? :conflict : :unprocessable_entity
          render json: {
            success: false,
            code: result[:code],
            message: result[:error]
          }, status: status
        end
      end

      private

      def find_order
        Order.find_by!(id: params[:id], client_id: current_client_id)
      end

      def order_json(order)
        {
          id: order.id,
          client_id: order.client_id,
          symbol: order.symbol,
          order_type: order.order_type,
          direction: order.direction,
          quantity: order.quantity,
          price: order.price&.to_f,
          time_in_force: order.time_in_force,
          status: order.status,
          filled_quantity: order.filled_quantity,
          reserved_amount: order.reserved_amount&.to_f,
          lock_version: order.lock_version,
          created_at: order.created_at.iso8601,
          updated_at: order.updated_at.iso8601
        }
      end

      def error_status(code)
        case code
        when 'validation_error' then :unprocessable_entity
        when 'insufficient_funds' then :unprocessable_entity
        when 'invalid_price' then :unprocessable_entity
        when 'version_conflict' then :conflict
        else :internal_server_error
        end
      end
    end
  end
end
