require 'singleton'

module Application
  module Services
    class MatchingEngine
      include Singleton

      def initialize
        @queue = Queue.new
        @max_queue_size = begin
          ENV.fetch('MATCHING_MAX_QUEUE', '1000').to_i
        rescue StandardError
          1000
        end
        # Avoid background thread in test to prevent race conditions with specs
        @worker_thread = Thread.new { run } unless Rails.env.test? || ENV['MATCHING_DISABLED'] == '1'
        Infrastructure::Observability::Metrics.set_gauge('matching_queue_size', 0)
      end

      def enqueue_order(order_hash)
        # In test, do nothing to keep deterministic order versions
        return true if Rails.env.test? || ENV['MATCHING_DISABLED'] == '1'

        if @queue.size >= @max_queue_size
          Rails.logger.warn("[MATCHING] Queue full (size=#{@queue.size}), dropping order: #{order_hash}")
          return false
        end
        @queue << order_hash
        Infrastructure::Observability::Metrics.set_gauge('matching_queue_size', @queue.size)
        Infrastructure::Observability::Metrics.inc_counter('orders_enqueued_total', { symbol: order_hash[:symbol], side: order_hash[:direction] })
        Rails.logger.info("[MATCHING] Enqueued order: #{order_hash}")
        true
      end

      private

      def run
        loop do
          order = @queue.pop
          process(order)
        end
      rescue StandardError => e
        Rails.logger.error("Matching engine error: #{e.message}\n#{e.backtrace.join("\n")}")
        retry
      end

      def process(order)
        Rails.logger.info("[MATCHING] Processing order: #{order}")
        repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
        begin
          current = repo.find(order[:order_id])
        rescue ::ActiveRecord::RecordNotFound
          Rails.logger.warn("[MATCHING] Order not found: #{order[:order_id]}")
          return
        end

        return unless current.status == 'new'

        # Basic cross for prototype: find an opposing NEW order with same symbol and equal quantity that crosses price rules
        opp_scope = Infrastructure::Persistence::ActiveRecord::OrderRecord.where(symbol: current.symbol, status: 'new').where.not(id: current.id)
        opposing_dir = current.direction == 'buy' ? 'sell' : 'buy'
        opp_scope = opp_scope.where(direction: opposing_dir, quantity: current.quantity)

        if current.order_type == 'limit' && current.price
          if current.direction == 'buy'
            opp_scope = opp_scope.where("price IS NULL OR price <= ?", current.price)
          else
            opp_scope = opp_scope.where("price IS NULL OR price >= ?", current.price)
          end
        end

        counter = opp_scope.order(:created_at).first
        unless counter
          # No match found; mark as working so it can be modified/cancelled later
          repo.update_status(current.id, 'working')
          Rails.logger.info("[MATCHING] Order moved to working: #{current.id}")
          return
        end

        # Execute trade for min qty (here equal by scope), price discovery: use counter.price if present else current.price else last mid (fallback)
        exec_qty = current.quantity
        exec_price = counter.price || current.price || 100.0

        ActiveRecord::Base.transaction do
          # Update orders to filled
          repo.update_status(current.id, 'filled')
          repo.update_status(counter.id, 'filled')

          # Portfolio funds: commit reserved for the BUY side(s)
          pf_repo = Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
          begin
            if current.direction == 'buy'
              pf = pf_repo.find_by_account_id(current.account_id)
              pf_repo.commit_reserved_funds(pf.id, exec_qty * exec_price)
            end
            if counter.direction == 'buy'
              pf2 = pf_repo.find_by_account_id(counter.account_id)
              pf_repo.commit_reserved_funds(pf2.id, exec_qty * exec_price)
            end
          rescue StandardError => e
            Rails.logger.warn("[MATCHING] Commit reserved funds failed: #{e.message}")
          end

          # Record trades (one per order for simplicity)
          Infrastructure::Persistence::ActiveRecord::TradeRecord.create!(
            order_id: current.id, account_id: current.account_id, symbol: current.symbol,
            quantity: exec_qty, price: exec_price, side: current.direction, status: 'executed'
          )
          Infrastructure::Persistence::ActiveRecord::TradeRecord.create!(
            order_id: counter.id, account_id: counter.account_id, symbol: counter.symbol,
            quantity: exec_qty, price: exec_price, side: counter.direction, status: 'executed'
          )
          Infrastructure::Observability::Metrics.inc_counter('trades_executed_total', { symbol: current.symbol })

          # Portfolio transaction logs (optional)
          begin
            Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.create!(
              account_id: current.account_id, operation_type: 'trade', amount: exec_qty * exec_price,
              currency: 'USD', status: 'settled', metadata: { order_id: current.id, match_with: counter.id }
            )
            Infrastructure::Persistence::ActiveRecord::PortfolioTransactionRecord.create!(
              account_id: counter.account_id, operation_type: 'trade', amount: exec_qty * exec_price,
              currency: 'USD', status: 'settled', metadata: { order_id: counter.id, match_with: current.id }
            )
          rescue StandardError => e
            Rails.logger.warn("[MATCHING] Failed to write portfolio transaction: #{e.message}")
          end

          # Audit
          Infrastructure::Persistence::ActiveRecord::AuditEventRecord.create!(
            event_type: 'trade.executed', entity_type: 'Order', entity_id: current.id, account_id: current.account_id,
            payload: { quantity: exec_qty, price: exec_price, counter_order: counter.id }
          )
          Infrastructure::Persistence::ActiveRecord::AuditEventRecord.create!(
            event_type: 'trade.executed', entity_type: 'Order', entity_id: counter.id, account_id: counter.account_id,
            payload: { quantity: exec_qty, price: exec_price, counter_order: current.id }
          )

          # Notifications: broadcast to each account order stream
          begin
            ActionCable.server.broadcast("orders:#{current.account_id}", { type: 'trade', order_id: current.id, quantity: exec_qty, price: exec_price, side: current.direction, ts: Time.now.utc.iso8601 })
            ActionCable.server.broadcast("orders:#{counter.account_id}", { type: 'trade', order_id: counter.id, quantity: exec_qty, price: exec_price, side: counter.direction, ts: Time.now.utc.iso8601 })
          rescue StandardError => e
            Rails.logger.warn("[MATCHING] Broadcast failed: #{e.message}")
          end
        end

        Infrastructure::Observability::Metrics.inc_counter('orders_matched_total', { symbol: current.symbol })
        Rails.logger.info("[MATCHING] Matched orders #{current.id} <> #{counter.id} @ #{exec_price} x #{exec_qty}")
      end
    end
  end
end
