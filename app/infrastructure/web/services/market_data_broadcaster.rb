module Infrastructure
  module Web
    module Services
      class MarketDataBroadcaster
        SYMBOLS = %w[AAPL MSFT AMZN TSLA].freeze

        def self.broadcast_tick(symbols = SYMBOLS)
          symbols.each do |sym|
            ActionCable.server.broadcast(stream_name(sym), quote_message(sym))
            # orderbook less frequent
            ActionCable.server.broadcast(stream_name(sym), snapshot_message(sym)) if rand < 0.3
            # occasionally send degraded/ok status to simulate source health
            if (Time.now.to_i % 40) < 2
              ActionCable.server.broadcast(stream_name(sym), { type: 'status', level: 'degraded', reason: 'source slow' })
            elsif (Time.now.to_i % 40) == 20
              ActionCable.server.broadcast(stream_name(sym), { type: 'status', level: 'ok' })
            end
          end
        end

        def self.stream_name(symbol)
          "market:#{symbol}"
        end

        def self.price_base(symbol)
          base = symbol.each_byte.sum % 200 + 50
          # random walk
          delta = (rand - 0.5) * 0.2
          base.to_f + delta
        end

        def self.snapshot_message(symbol)
          mid = price_base(symbol)
          {
            type: 'orderbook',
            symbol: symbol,
            bids: [[(mid - 0.02).round(3), 100], [(mid - 0.03).round(3), 50]],
            asks: [[(mid + 0.02).round(3), 100], [(mid + 0.03).round(3), 50]],
            ts: Time.now.utc.iso8601
          }
        end

        def self.quote_message(symbol)
          mid = price_base(symbol)
          {
            type: 'quote',
            symbol: symbol,
            bid: (mid - 0.005).round(3),
            ask: (mid + 0.005).round(3),
            mid: mid.round(3),
            ts: Time.now.utc.iso8601
          }
        end
      end
    end
  end
end
