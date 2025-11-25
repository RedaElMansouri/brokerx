# frozen_string_literal: true

module Application
  module Services
    # TradingSaga orchestrates the complete trading workflow using the Saga pattern.
    #
    # A saga is a sequence of local transactions where each step has a compensating
    # action that can undo its effects if a subsequent step fails.
    #
    # Trading Saga Steps:
    # 1. Validate Order      → Compensate: N/A (no side effects)
    # 2. Reserve Funds       → Compensate: Release reserved funds
    # 3. Create Order        → Compensate: Cancel order
    # 4. Submit to Matching  → Compensate: N/A (async, handled by matching engine)
    # 5. Execute Trade       → Compensate: Reverse trade (if possible)
    # 6. Update Portfolio    → Compensate: Reverse portfolio changes
    # 7. Notify Client       → Compensate: N/A (notifications are idempotent)
    #
    # Events emitted:
    # - saga.started
    # - saga.step.completed
    # - saga.step.failed
    # - saga.compensating
    # - saga.completed
    # - saga.failed
    #
    class TradingSaga
      STEPS = %i[
        validate_order
        reserve_funds
        create_order
        submit_to_matching
      ].freeze

      SagaResult = Struct.new(:success, :order_id, :saga_id, :steps_completed, :error, :compensated, keyword_init: true)
      StepResult = Struct.new(:success, :data, :error, keyword_init: true)

      attr_reader :saga_id, :correlation_id, :steps_completed, :compensation_log

      def initialize(order_repo: nil, portfolio_repo: nil, matching_engine: nil)
        @order_repo = order_repo || Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        @portfolio_repo = portfolio_repo || Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
        @matching_engine = matching_engine || Application::Services::MatchingEngine.instance
        @saga_id = SecureRandom.uuid
        @correlation_id = nil
        @steps_completed = []
        @compensation_log = []
        @context = {}
      end

      # Execute the trading saga for a given order DTO
      # @param dto [Application::Dtos::PlaceOrderDto] the order to process
      # @param client_id [Integer] the client placing the order
      # @param correlation_id [String] optional correlation ID for tracing
      # @return [SagaResult]
      def execute(dto:, client_id:, correlation_id: nil)
        @correlation_id = correlation_id || SecureRandom.uuid
        @context = { dto: dto, client_id: client_id, order: nil, reserved_amount: 0 }

        emit_event('saga.started', { saga_id: @saga_id, correlation_id: @correlation_id, client_id: client_id })
        log_info("Saga started for client #{client_id}, symbol: #{dto.symbol}")

        begin
          STEPS.each do |step|
            result = execute_step(step)
            unless result.success
              log_error("Step #{step} failed: #{result.error}")
              emit_event('saga.step.failed', { saga_id: @saga_id, step: step, error: result.error })
              compensate!
              return SagaResult.new(
                success: false,
                order_id: @context[:order]&.id,
                saga_id: @saga_id,
                steps_completed: @steps_completed,
                error: result.error,
                compensated: true
              )
            end

            @steps_completed << step
            emit_event('saga.step.completed', { saga_id: @saga_id, step: step, data: result.data })
            log_info("Step #{step} completed")
          end

          emit_event('saga.completed', { saga_id: @saga_id, order_id: @context[:order]&.id })
          log_info("Saga completed successfully, order_id: #{@context[:order]&.id}")

          SagaResult.new(
            success: true,
            order_id: @context[:order].id,
            saga_id: @saga_id,
            steps_completed: @steps_completed,
            error: nil,
            compensated: false
          )
        rescue StandardError => e
          log_error("Saga unexpected error: #{e.message}")
          emit_event('saga.failed', { saga_id: @saga_id, error: e.message })
          compensate!
          SagaResult.new(
            success: false,
            order_id: @context[:order]&.id,
            saga_id: @saga_id,
            steps_completed: @steps_completed,
            error: e.message,
            compensated: true
          )
        end
      end

      private

      def execute_step(step)
        send("step_#{step}")
      rescue StandardError => e
        StepResult.new(success: false, error: e.message)
      end

      # STEP 1: Validate Order
      def step_validate_order
        dto = @context[:dto]
        client_id = @context[:client_id]

        validation_service = Application::Services::OrderValidationService.new(@portfolio_repo)
        errors = validation_service.validate_pre_trade(dto, client_id)

        if errors.any?
          return StepResult.new(success: false, error: "Validation failed: #{errors.join(', ')}")
        end

        # Store calculated cost for later steps
        @context[:order_cost] = validation_service.send(:calculate_order_cost, dto)

        StepResult.new(success: true, data: { validated: true, order_cost: @context[:order_cost] })
      end

      # STEP 2: Reserve Funds
      def step_reserve_funds
        dto = @context[:dto]
        client_id = @context[:client_id]

        # Only reserve for buy orders
        if dto.direction == 'buy'
          portfolio = @portfolio_repo.find_by_account_id(client_id)
          raise "Portfolio not found for client #{client_id}" unless portfolio

          amount = @context[:order_cost] || 0
          @portfolio_repo.reserve_funds(portfolio.id, amount)
          @context[:reserved_amount] = amount
          @context[:portfolio_id] = portfolio.id

          # Register compensation
          @compensation_log << { step: :reserve_funds, action: :release_funds, portfolio_id: portfolio.id, amount: amount }
        end

        StepResult.new(success: true, data: { reserved: @context[:reserved_amount] })
      end

      # Compensation: Release reserved funds
      def compensate_reserve_funds(compensation)
        log_info("Compensating: releasing #{compensation[:amount]} for portfolio #{compensation[:portfolio_id]}")
        @portfolio_repo.release_funds(compensation[:portfolio_id], compensation[:amount])
      rescue StandardError => e
        log_error("Compensation failed for reserve_funds: #{e.message}")
      end

      # STEP 3: Create Order
      def step_create_order
        dto = @context[:dto]
        client_id = @context[:client_id]

        order = @order_repo.create({
          account_id: client_id,
          symbol: dto.symbol,
          order_type: dto.order_type,
          direction: dto.direction,
          quantity: dto.quantity,
          price: dto.price,
          time_in_force: dto.time_in_force,
          status: 'new',
          reserved_amount: @context[:reserved_amount]
        })

        @context[:order] = order

        # Register compensation
        @compensation_log << { step: :create_order, action: :cancel_order, order_id: order.id }

        # Audit event
        create_audit_event('order.created', 'Order', order.id, client_id, {
          symbol: order.symbol,
          type: order.order_type,
          direction: order.direction,
          qty: order.quantity,
          price: order.price,
          saga_id: @saga_id
        })

        StepResult.new(success: true, data: { order_id: order.id })
      end

      # Compensation: Cancel order
      def compensate_create_order(compensation)
        log_info("Compensating: cancelling order #{compensation[:order_id]}")
        @order_repo.update_status(compensation[:order_id], 'cancelled')

        create_audit_event('order.cancelled', 'Order', compensation[:order_id], @context[:client_id], {
          reason: 'saga_compensation',
          saga_id: @saga_id
        })
      rescue StandardError => e
        log_error("Compensation failed for create_order: #{e.message}")
      end

      # STEP 4: Submit to Matching Engine
      def step_submit_to_matching
        order = @context[:order]

        # Create outbox event for async processing
        create_outbox_event('order.created', 'Order', order.id, {
          symbol: order.symbol,
          order_type: order.order_type,
          direction: order.direction,
          quantity: order.quantity,
          price: order.price,
          time_in_force: order.time_in_force,
          account_id: order.account_id,
          saga_id: @saga_id
        })

        # Also directly enqueue for immediate matching (optional, outbox will also trigger)
        @matching_engine.enqueue_order({
          order_id: order.id,
          symbol: order.symbol,
          direction: order.direction,
          order_type: order.order_type,
          quantity: order.quantity,
          price: order.price
        })

        StepResult.new(success: true, data: { submitted: true })
      end

      # Compensation Orchestrator
      def compensate!
        return if @compensation_log.empty?

        emit_event('saga.compensating', { saga_id: @saga_id, steps_to_compensate: @compensation_log.map { |c| c[:step] } })
        log_info("Starting compensation for #{@compensation_log.size} steps")

        # Compensate in reverse order
        @compensation_log.reverse.each do |compensation|
          method_name = "compensate_#{compensation[:step]}"
          if respond_to?(method_name, true)
            send(method_name, compensation)
          else
            log_warn("No compensation method found for step: #{compensation[:step]}")
          end
        end

        log_info("Compensation completed")
      end

      # Event Helpers
      def emit_event(event_type, payload)
        create_outbox_event(event_type, 'Saga', @saga_id, payload.merge(correlation_id: @correlation_id))
      rescue StandardError => e
        log_warn("Failed to emit event #{event_type}: #{e.message}")
      end

      def create_outbox_event(event_type, entity_type, entity_id, payload)
        Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.create!(
          event_type: event_type,
          status: 'pending',
          correlation_id: @correlation_id,
          entity_type: entity_type,
          entity_id: entity_id,
          payload: payload,
          produced_at: Time.now.utc
        )
      end

      def create_audit_event(event_type, entity_type, entity_id, account_id, payload)
        Infrastructure::Persistence::ActiveRecord::AuditEventRecord.create!(
          event_type: event_type,
          entity_type: entity_type,
          entity_id: entity_id,
          account_id: account_id,
          payload: payload.merge(saga_id: @saga_id)
        )
      rescue StandardError => e
        log_warn("Failed to create audit event: #{e.message}")
      end

      # Logging
      def log_info(message)
        Rails.logger.info("[SAGA:#{@saga_id}] #{message}")
      end

      def log_warn(message)
        Rails.logger.warn("[SAGA:#{@saga_id}] #{message}")
      end

      def log_error(message)
        Rails.logger.error("[SAGA:#{@saga_id}] #{message}")
      end
    end
  end
end
