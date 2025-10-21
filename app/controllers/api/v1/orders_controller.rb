module Api
  module V1
    class OrdersController < ApplicationController
      # skip CSRF check for API endpoints if the helper exists (safe during early loading)
      if respond_to?(:skip_before_action)
        begin
          skip_before_action :verify_authenticity_token
        rescue ArgumentError
          # ignore if callback is not defined in this loading context
        end
      end

      def create
        # Rely on Rails autoloading; domain/application are eager-loaded

        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

  dto = ::Dtos::PlaceOrderDto.new(
          account_id: client_id,
          symbol: params[:symbol],
          order_type: params[:order_type],
          direction: params[:direction],
          quantity: params[:quantity].to_i,
          price: params[:price] ? params[:price].to_f : nil,
          time_in_force: params[:time_in_force] || 'DAY'
        )

  validation_service = ::Services::OrderValidationService.new(portfolio_repository)
        errors = validation_service.validate_pre_trade(dto, client_id)
        unless errors.empty?
          return render json: { success: false, errors: errors }, status: :unprocessable_entity
        end

        # For buy orders, reserve funds
        if dto.direction == 'buy'
          begin
            portfolio_repository.reserve_funds(portfolio_for_client(client_id).id, validation_service.send(:calculate_order_cost, dto))
          rescue => e
            return render json: { success: false, error: e.message }, status: :unprocessable_entity
          end
        end

        # Persist order for tracking/observability
        order = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new.create({
          account_id: dto.account_id,
          symbol: dto.symbol,
          order_type: dto.order_type,
          direction: dto.direction,
          quantity: dto.quantity,
          price: dto.price,
          time_in_force: dto.time_in_force,
          status: 'new',
          reserved_amount: (dto.direction == 'buy' ? validation_service.send(:calculate_order_cost, dto) : 0)
        })

        # Enqueue to matching engine (in-memory simple matcher)
        ::Services::MatchingEngine.instance.enqueue_order(dto.to_h.merge(order_id: order.id))

        render json: { success: true, order_id: order.id, message: 'Order accepted and queued for matching' }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      def show
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        order = repo.find(params[:id])
        return render(json: { success: false, error: 'Not found' }, status: :not_found) unless order
        return render(json: { success: false, error: 'Forbidden' }, status: :forbidden) unless order.account_id == client_id

        render json: {
          success: true,
          id: order.id,
          account_id: order.account_id,
          symbol: order.symbol,
          order_type: order.order_type,
          direction: order.direction,
          quantity: order.quantity,
          price: order.price,
          time_in_force: order.time_in_force,
          status: order.status,
          reserved_amount: order.reserved_amount,
          created_at: order.created_at,
          updated_at: order.updated_at
        }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      def destroy
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        order = repo.find(params[:id])
        return render(json: { success: false, error: 'Not found' }, status: :not_found) unless order
        return render(json: { success: false, error: 'Forbidden' }, status: :forbidden) unless order.account_id == client_id

        # Only cancel if not already terminal
        if %w[filled cancelled].include?(order.status)
          return render json: { success: false, error: 'Order already finalized' }, status: :unprocessable_entity
        end

        # If it was a buy with reserved funds, release them
        if order.direction == 'buy' && order.reserved_amount.to_f > 0
          begin
            pf = portfolio_for_client(client_id)
            portfolio_repository.release_funds(pf.id, order.reserved_amount)
          rescue => e
            return render json: { success: false, error: "Failed to release funds: #{e.message}" }, status: :internal_server_error
          end
        end

        repo.update_status(order.id, 'cancelled')
        render json: { success: true, status: 'cancelled' }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      private

      # No more manual load_dependencies

      def token_to_client_id(token)
        return nil unless token
        begin
          payload, _ = JWT.decode(
            token,
            Rails.application.secret_key_base,
            true,
            {
              algorithm: 'HS256',
              iss: 'brokerx',
              verify_iss: true,
              aud: 'brokerx.web',
              verify_aud: true,
              verify_expiration: true
            }
          )
          payload['client_id']
        rescue JWT::DecodeError => e
          Rails.logger.warn("JWT decode error: #{e.class}: #{e.message}")
          nil
        end
      end

      def portfolio_repository
        @portfolio_repository ||= ::Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
      end

      def portfolio_for_client(client_id)
        portfolio_repository.find_by_account_id(client_id)
      end
    end
  end
end
