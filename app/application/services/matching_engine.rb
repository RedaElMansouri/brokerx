require 'singleton'

module Services
  class MatchingEngine
      include Singleton

      def initialize
        @queue = Queue.new
        @max_queue_size = (ENV.fetch('MATCHING_MAX_QUEUE', '1000').to_i rescue 1000)
        @worker_thread = Thread.new { run }
      end

      def enqueue_order(order_hash)
        if @queue.size >= @max_queue_size
          Rails.logger.warn("[MATCHING] Queue full (size=#{@queue.size}), dropping order: #{order_hash}")
          return false
        end
        @queue << order_hash
        Rails.logger.info("[MATCHING] Enqueued order: #{order_hash}")
        true
      end

      private

      def run
        loop do
          order = @queue.pop
          process(order)
        end
      rescue => e
        Rails.logger.error("Matching engine error: #{e.message}\n#{e.backtrace.join("\n")}")
        retry
      end

      def process(order)
        # Minimal processing for prototype: log and pretend to match
        Rails.logger.info("[MATCHING] Processing order: #{order}")
        # TODO: integrate real order book and match engine
        sleep 0.1
        # Simulated execution log for observability
        begin
          Infrastructure::Persistence::ActiveRecord::TradeRecord.create!(
            order_id: order[:order_id],
            account_id: order[:account_id],
            symbol: order[:symbol],
            quantity: order[:quantity],
            price: (order[:price] || 0),
            side: order[:direction],
            status: 'executed'
          )
        rescue => e
          Rails.logger.warn("[MATCHING] Failed to log trade: #{e.message}")
        end
        Rails.logger.info("[MATCHING] Order processed: #{order}")
      end
  end
end
