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
        load_dependencies

        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        dto = Application::Dtos::PlaceOrderDto.new(
          account_id: client_id,
          symbol: params[:symbol],
          order_type: params[:order_type],
          direction: params[:direction],
          quantity: params[:quantity].to_i,
          price: params[:price] ? params[:price].to_f : nil,
          time_in_force: params[:time_in_force] || 'DAY'
        )

        validation_service = Application::Services::OrderValidationService.new(portfolio_repository)
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

        # Enqueue to matching engine (in-memory simple matcher)
        Application::Services::MatchingEngine.instance.enqueue_order(dto.to_h)

        render json: { success: true, message: 'Order accepted and queued for matching' }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      private

      def load_dependencies
        # reuse same manual loads used elsewhere
        load 'app/domain/shared/value_object.rb' if File.exist?(Rails.root.join('app','domain','shared','value_object.rb'))
        load 'app/domain/shared/entity.rb' if File.exist?(Rails.root.join('app','domain','shared','entity.rb'))
        load 'app/domain/shared/repository.rb' if File.exist?(Rails.root.join('app','domain','shared','repository.rb'))

        load 'app/application/dtos/place_order_dto.rb' if File.exist?(Rails.root.join('app','application','dtos','place_order_dto.rb'))
        load 'app/application/services/order_validation_service.rb' if File.exist?(Rails.root.join('app','application','services','order_validation_service.rb'))
        load 'app/application/services/matching_engine.rb' if File.exist?(Rails.root.join('app','application','services','matching_engine.rb'))

        load 'app/domain/clients/entities/portfolio.rb' if File.exist?(Rails.root.join('app','domain','clients','entities','portfolio.rb'))
        load 'app/domain/clients/repositories/portfolio_repository.rb' if File.exist?(Rails.root.join('app','domain','clients','repositories','portfolio_repository.rb'))

        load 'app/infrastructure/persistence/active_record/portfolio_record.rb' if File.exist?(Rails.root.join('app','infrastructure','persistence','active_record','portfolio_record.rb'))
        load 'app/models/portfolio_record.rb' if File.exist?(Rails.root.join('app','models','portfolio_record.rb'))
        load 'app/infrastructure/persistence/repositories/active_record_portfolio_repository.rb' if File.exist?(Rails.root.join('app','infrastructure','persistence','repositories','active_record_portfolio_repository.rb'))
      end

      def token_to_client_id(token)
        return nil unless token
        begin
          payload = JWT.decode(token, Rails.application.secret_key_base)[0]
          payload['client_id']
        rescue
          nil
        end
      end

      def portfolio_repository
        @portfolio_repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
      end

      def portfolio_for_client(client_id)
        portfolio_repository.find_by_account_id(client_id)
      end
    end
  end
end
