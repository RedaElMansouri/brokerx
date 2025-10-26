module Api
  module V1
    class OrdersController < ApplicationController
      # Endpoints API : pas de vérification CSRF nécessaire
      skip_before_action :verify_authenticity_token

      def create
        # Place un ordre (validation + éventuelle réservation de fonds) avec idempotence optionnelle

        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        begin
          p = order_params
        rescue ActionController::ParameterMissing => e
          return render json: { success: false, code: 'bad_request', message: e.message }, status: :bad_request
        end
        client_order_id = p[:client_order_id].presence
        dto = Application::Dtos::PlaceOrderDto.new(
          account_id: client_id,
          symbol: p[:symbol],
          order_type: p[:order_type],
          direction: p[:direction],
          quantity: p[:quantity].to_i,
          price: p[:price].present? ? p[:price].to_f : nil,
          time_in_force: p[:time_in_force] || 'DAY'
        )

        validation_service = Application::Services::OrderValidationService.new(portfolio_repository)
        errors = validation_service.validate_pre_trade(dto, client_id)
        return render json: { success: false, errors: errors }, status: :unprocessable_content unless errors.empty?

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        created_order = nil
        ::ActiveRecord::Base.transaction do
          # Idempotence côté order
          if client_order_id
            existing = Infrastructure::Persistence::ActiveRecord::OrderRecord.find_by(account_id: client_id, client_order_id: client_order_id)
            if existing
              return render json: { success: true, order_id: existing.id, lock_version: existing.lock_version, message: 'Idempotent replay' }, status: :ok
            end
          end

          # Réserver les fonds pour les ordres d'achat
          if dto.direction == 'buy'
            begin
              portfolio_repository.reserve_funds(portfolio_for_client(client_id).id,
              validation_service.send(:calculate_order_cost, dto))
            rescue StandardError => e
              return render json: { success: false, error: e.message }, status: :unprocessable_content
            end
          end

          # Persister l'ordre pour le suivi/observabilité
          created_order = repo.create({
            account_id: dto.account_id,
            symbol: dto.symbol,
            order_type: dto.order_type,
            direction: dto.direction,
            quantity: dto.quantity,
            price: dto.price,
            time_in_force: dto.time_in_force,
            status: 'new',
            client_order_id: client_order_id,
            reserved_amount: (if dto.direction == 'buy'
                validation_service.send(
                :calculate_order_cost, dto
                )
            else
              0
            end)
            })

          # Audit
          Infrastructure::Persistence::ActiveRecord::AuditEventRecord.create!(
            event_type: 'order.created',
            entity_type: 'Order',
            entity_id: created_order.id,
            account_id: client_id,
            payload: { symbol: created_order.symbol, type: created_order.order_type, direction: created_order.direction, qty: created_order.quantity, price: created_order.price, reserved_amount: created_order.reserved_amount, client_order_id: created_order.client_order_id }
          )
        end

        # Envoyer à l'engine de matching (simple, en mémoire)
        Application::Services::MatchingEngine.instance.enqueue_order(dto.to_h.merge(order_id: created_order.id))

        render json: { success: true, order_id: created_order.id, lock_version: created_order.lock_version, message: 'Order accepted and queued for matching' }
      end

      def show
        # Récupérer un ordre si l'utilisateur est propriétaire
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        begin
          order = repo.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          return render(json: { success: false, code: 'not_found', message: 'Not found' }, status: :not_found)
        end
        unless order
          return render(json: { success: false, code: 'not_found', message: 'Not found' },
                        status: :not_found)
        end

        unless order.account_id == client_id
          return render(json: { success: false, code: 'forbidden', message: 'Forbidden' },
                        status: :forbidden)
        end

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
          lock_version: order.lock_version,
          created_at: order.created_at,
          updated_at: order.updated_at
        }
      end

      def destroy
        # Annuler un ordre non finalisé et libérer les fonds réservés
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        order = repo.find(params[:id])
        unless order
          return render(json: { success: false, code: 'not_found', message: 'Not found' },
                        status: :not_found)
        end

        unless order.account_id == client_id
          return render(json: { success: false, error: 'Forbidden' },
                        status: :forbidden)
        end

        # Only cancel if not already terminal
        if %w[filled cancelled].include?(order.status)
          return render json: { success: false, code: 'invalid_state', message: 'Order already finalized' },
                        status: :unprocessable_content
        end

        # If it was a buy with reserved funds, release them
        if order.direction == 'buy' && order.reserved_amount.to_f > 0
          begin
            pf = portfolio_for_client(client_id)
            portfolio_repository.release_funds(pf.id, order.reserved_amount)
          rescue StandardError => e
            return render json: { success: false, code: 'funds_release_failed', message: "Failed to release funds: #{e.message}" },
                          status: :internal_server_error
          end
        end

        repo.update_status(order.id, 'cancelled')
        order.reload
        render json: { success: true, status: 'cancelled', lock_version: order.lock_version, message: 'Order cancelled' }
      end

      # UC-06: modifier un ordre (remplacement) avec verrouillage optimiste
      def replace
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        begin
          p = replace_params
        rescue ActionController::ParameterMissing => e
          return render json: { success: false, code: 'bad_request', message: e.message }, status: :bad_request
        end

        client_version = p[:client_version]
        unless client_version
          return render json: { success: false, code: 'missing_version', message: 'client_version is required' }, status: :bad_request
        end

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        begin
          order = repo.find(params[:id])
        rescue ::ActiveRecord::RecordNotFound
          return render(json: { success: false, code: 'not_found', message: 'Not found' }, status: :not_found)
        end

        unless order.account_id == client_id
          return render(json: { success: false, code: 'forbidden', message: 'Forbidden' }, status: :forbidden)
        end

        if %w[filled cancelled].include?(order.status)
          return render json: { success: false, code: 'invalid_state', message: 'Order already finalized' }, status: :unprocessable_content
        end

        # Vérifier la version optimiste
        if order.lock_version.to_i != client_version.to_i
          return render json: { success: false, code: 'version_conflict', message: 'Order has been modified by another process' }, status: :conflict
        end

        # Calcul des nouveaux attributs
        new_quantity = (p[:quantity].presence || order.quantity).to_i
        new_price = p.key?(:price) ? (p[:price].present? ? p[:price].to_f : nil) : order.price
        new_tif = p[:time_in_force].presence || order.time_in_force

        # Re-valider les règles métier
        dto = Application::Dtos::PlaceOrderDto.new(
          account_id: order.account_id,
          symbol: order.symbol,
          order_type: order.order_type,
          direction: order.direction,
          quantity: new_quantity,
          price: new_price,
          time_in_force: new_tif
        )
        validation_service = Application::Services::OrderValidationService.new(portfolio_repository)
        errors = validation_service.validate_pre_trade(dto, client_id)
        return render json: { success: false, errors: errors }, status: :unprocessable_content unless errors.empty?

        # Ajuster les fonds + mise à jour atomiques
        ::ActiveRecord::Base.transaction do
          # Ajuster les fonds réservés si achat
          if order.direction == 'buy'
            old_reserved = order.reserved_amount.to_f
            new_cost = validation_service.send(:calculate_order_cost, dto)
            delta = new_cost.to_f - old_reserved
            pf = portfolio_for_client(client_id)
            if delta > 0
              begin
                portfolio_repository.reserve_funds(pf.id, delta)
              rescue StandardError => e
                return render json: { success: false, code: 'funds_reserve_failed', message: "Failed to reserve additional funds: #{e.message}" }, status: :unprocessable_content
              end
            elsif delta < 0
              begin
                portfolio_repository.release_funds(pf.id, -delta)
              rescue StandardError => e
                return render json: { success: false, code: 'funds_release_failed', message: "Failed to release funds: #{e.message}" }, status: :internal_server_error
              end
            end
            order.reserved_amount = new_cost
          end

          # Appliquer la mise à jour (verrouillage optimiste via lock_version)
          begin
            order.lock_version = client_version.to_i # s'assurer que la mise à jour respecte la version du client
            order.assign_attributes(quantity: new_quantity, price: new_price, time_in_force: new_tif)
            order.save!
          rescue ::ActiveRecord::StaleObjectError
            return render json: { success: false, code: 'version_conflict', message: 'Order has been modified by another process' }, status: :conflict
          rescue ::ActiveRecord::RecordInvalid => e
            return render json: { success: false, code: 'validation_failed', message: e.record.errors.full_messages.join(', ') }, status: :unprocessable_content
          end

          # Audit
          Infrastructure::Persistence::ActiveRecord::AuditEventRecord.create!(
            event_type: 'order.replaced',
            entity_type: 'Order',
            entity_id: order.id,
            account_id: client_id,
            payload: { quantity: order.quantity, price: order.price, time_in_force: order.time_in_force, reserved_amount: order.reserved_amount }
          )
        end

        render json: {
          success: true,
          id: order.id,
          status: order.status,
          quantity: order.quantity,
          price: order.price,
          time_in_force: order.time_in_force,
          reserved_amount: order.reserved_amount,
          lock_version: order.lock_version,
          message: 'Order modified'
        }
      end

      # UC-06: annuler via POST avec client_version (alias plus explicite de destroy)
      def cancel
        token = request.headers['Authorization']&.to_s&.gsub(/^Bearer\s+/i, '')
        client_id = token_to_client_id(token)
        return render(json: { success: false, error: 'Unauthorized' }, status: :unauthorized) unless client_id

        p = params.permit(:client_version)
        client_version = p[:client_version]
        unless client_version
          return render json: { success: false, code: 'missing_version', message: 'client_version is required' }, status: :bad_request
        end

        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        begin
          order = repo.find(params[:id])
        rescue ::ActiveRecord::RecordNotFound
          return render(json: { success: false, code: 'not_found', message: 'Not found' }, status: :not_found)
        end

        unless order.account_id == client_id
          return render(json: { success: false, code: 'forbidden', message: 'Forbidden' }, status: :forbidden)
        end

        if %w[filled cancelled].include?(order.status)
          return render json: { success: false, code: 'invalid_state', message: 'Order already finalized' }, status: :unprocessable_content
        end

        if order.lock_version.to_i != client_version.to_i
          return render json: { success: false, code: 'version_conflict', message: 'Order has been modified by another process' }, status: :conflict
        end

        ::ActiveRecord::Base.transaction do
          if order.direction == 'buy' && order.reserved_amount.to_f > 0
            pf = portfolio_for_client(client_id)
            begin
              portfolio_repository.release_funds(pf.id, order.reserved_amount)
            rescue StandardError => e
              return render json: { success: false, code: 'funds_release_failed', message: "Failed to release funds: #{e.message}" }, status: :internal_server_error
            end
          end

          begin
            order.lock_version = client_version.to_i
            order.update!(status: 'cancelled')
          rescue ::ActiveRecord::StaleObjectError
            return render json: { success: false, code: 'version_conflict', message: 'Order has been modified by another process' }, status: :conflict
          end

          # Audit
          Infrastructure::Persistence::ActiveRecord::AuditEventRecord.create!(
            event_type: 'order.cancelled',
            entity_type: 'Order',
            entity_id: order.id,
            account_id: client_id,
            payload: { reserved_amount_released: order.reserved_amount }
          )
        end

        render json: { success: true, status: 'cancelled', lock_version: order.lock_version, message: 'Order cancelled' }
      end

      private

      # Aides privées

      def token_to_client_id(token)
        return nil unless token

        begin
          payload, = JWT.decode(
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

      def order_params
        params.require(:order).permit(:symbol, :order_type, :direction, :quantity, :price, :time_in_force, :client_order_id)
      end

      def replace_params
        params.require(:order).permit(:quantity, :price, :time_in_force, :client_version)
      end
    end
  end
end
