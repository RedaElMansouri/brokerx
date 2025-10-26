# Simulate market data by periodically broadcasting quotes and occasional orderbook snapshots.
# Runs only in development mode to avoid side effects in test/production.
Rails.application.config.after_initialize do
  if Rails.env.development?
    Thread.new do
      loop do
        begin
          ::Infrastructure::Web::Services::MarketDataBroadcaster.broadcast_tick
        rescue => e
          Rails.logger.warn("MarketDataSimulator error: #{e.message}")
        ensure
          sleep 2
        end
      end
    end
  end
end
