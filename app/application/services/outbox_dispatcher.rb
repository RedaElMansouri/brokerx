require 'singleton'

module Application
  module Services
    class OutboxDispatcher
      include Singleton

      POLL_INTERVAL = (ENV['OUTBOX_POLL_INTERVAL'] || '0.5').to_f
      MAX_PER_TICK = (ENV['OUTBOX_MAX_PER_TICK'] || '50').to_i

      def initialize
        @running = false
      end

      def start!
        return if @running
        @running = true
        Thread.new { run } unless Rails.env.test?
      end

      def run
        Rails.logger.info('[OUTBOX] dispatcher started')
        loop do
          dispatch_pending
          sleep POLL_INTERVAL
        end
      rescue StandardError => e
        Rails.logger.error("[OUTBOX] fatal: #{e.message}\n#{e.backtrace.join("\n")}")
        retry
      end

      def dispatch_pending
        rel = ::Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.pending.order(:created_at).limit(MAX_PER_TICK)
        count = rel.count
        Infrastructure::Observability::Metrics.set_gauge('outbox_inflight', count)
        rel.each do |evt|
          process_event(evt)
        end
      end

      private

      def process_event(evt)
        ::ActiveRecord::Base.transaction do
          evt.update!(status: 'processing')
        end

        begin
          case evt.event_type
          when 'order.created'
            handle_order_created(evt)
          when 'execution.report'
            handle_execution_report(evt)
          when /^saga\./
            handle_saga_event(evt)
          else
            Rails.logger.warn("[OUTBOX] Unknown event type: #{evt.event_type}")
          end

          evt.update!(status: 'processed', produced_at: evt.produced_at || Time.now.utc)
          ::Infrastructure::Observability::Metrics.inc_counter('outbox_events_total', { type: evt.event_type, status: 'processed' })
        rescue StandardError => e
          evt.update!(status: 'failed', attempts: evt.attempts + 1, last_error: e.message)
          ::Infrastructure::Observability::Metrics.inc_counter('outbox_events_total', { type: evt.event_type, status: 'failed' })
          ::Infrastructure::Observability::Metrics.inc_counter('outbox_dispatch_errors_total', { type: evt.event_type })
          Rails.logger.error("[OUTBOX] dispatch error for #{evt.id} type=#{evt.event_type}: #{e.message}")
        end
      end

      def handle_order_created(evt)
        payload = evt.payload || {}
        order_id = evt.entity_id
        sym = payload['symbol']
        direction = payload['direction']
        order_type = payload['order_type']
        quantity = payload['quantity']
        price = payload['price']

        Application::Services::MatchingEngine.instance.enqueue_order({
          order_id: order_id,
          symbol: sym,
          direction: direction,
          order_type: order_type,
          quantity: quantity,
          price: price
        })
      end

      def handle_execution_report(evt)
        payload = evt.payload || {}
        order_id = payload['order_id'] || evt.entity_id
        status = payload['status']
        quantity = payload['quantity']
        price = payload['price']

        # Push real-time notification (trade already broadcast; here generic status)
        begin
          if order_id && status
            ActionCable.server.broadcast("orders_status:#{order_id}", {
              type: 'execution.report', order_id: order_id, status: status, quantity: quantity, price: price, ts: Time.now.utc.iso8601
            })
          end
        rescue StandardError => e
          Rails.logger.warn("[OUTBOX] execution.report broadcast failed: #{e.message}")
        end

        # Email fallback (simplified): find account email
        begin
          if evt.entity_type == 'Order' && order_id
            order = ::Infrastructure::Persistence::ActiveRecord::OrderRecord.find_by(id: order_id)
            if order
              client = ::Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(id: order.account_id)
              if client&.email
                ExecutionReportMailer.with(email: client.email, order_id: order_id, status: status, quantity: quantity, price: price).execution_report.deliver_later
              end
            end
          end
        rescue StandardError => e
          Rails.logger.warn("[OUTBOX] execution.report mail failed: #{e.message}")
        end
      end

      # Handle saga lifecycle events for observability
      def handle_saga_event(evt)
        payload = evt.payload || {}
        saga_id = payload['saga_id']
        event_subtype = evt.event_type.sub('saga.', '')

        Rails.logger.info("[OUTBOX] Saga event: #{evt.event_type} saga_id=#{saga_id}")

        # Update metrics based on saga state
        case event_subtype
        when 'started'
          ::Infrastructure::Observability::Metrics.inc_counter('saga_started_total', {})
        when 'completed'
          ::Infrastructure::Observability::Metrics.inc_counter('saga_completed_total', { status: 'success' })
        when 'failed'
          ::Infrastructure::Observability::Metrics.inc_counter('saga_completed_total', { status: 'failed' })
        when 'compensating'
          ::Infrastructure::Observability::Metrics.inc_counter('saga_compensations_total', {})
        when 'step.completed'
          step = payload['step']
          ::Infrastructure::Observability::Metrics.inc_counter('saga_steps_total', { step: step.to_s, status: 'completed' })
        when 'step.failed'
          step = payload['step']
          ::Infrastructure::Observability::Metrics.inc_counter('saga_steps_total', { step: step.to_s, status: 'failed' })
        end

        # Broadcast saga status updates for real-time monitoring
        begin
          correlation_id = payload['correlation_id']
          if correlation_id
            ActionCable.server.broadcast("saga:#{correlation_id}", {
              type: evt.event_type,
              saga_id: saga_id,
              payload: payload,
              ts: Time.now.utc.iso8601
            })
          end
        rescue StandardError => e
          Rails.logger.warn("[OUTBOX] saga broadcast failed: #{e.message}")
        end
      end
    end
  end
end
