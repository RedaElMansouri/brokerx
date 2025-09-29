require 'singleton'

module Application
  module Services
    class MatchingEngine
      include Singleton

      def initialize
        @queue = Queue.new
        @worker_thread = Thread.new { run }
      end

      def enqueue_order(order_hash)
        @queue << order_hash
        Rails.logger.info("[MATCHING] Enqueued order: #{order_hash}")
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
        Rails.logger.info("[MATCHING] Order processed: #{order}")
      end
    end
  end
end
