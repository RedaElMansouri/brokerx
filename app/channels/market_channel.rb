class MarketChannel < ApplicationCable::Channel
  # Client subscribes with params: { symbols: ['AAPL', 'MSFT'], mode: 'normal'|'throttled' }
  def subscribed
    reject unless connection.current_client_id

    @symbols = Array(params[:symbols]).map { |s| s.to_s.upcase }.uniq
    reject if @symbols.empty?

    @mode = (params[:mode] || 'normal').to_s

    @symbols.each do |sym|
      stream_from stream_name(sym)
      # Send initial snapshots quickly so client sees data immediately
      transmit snapshot_message(sym)
      transmit quote_message(sym)
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  private

  def stream_name(symbol)
    "market:#{symbol}"
  end

  def snapshot_message(symbol)
    {
      type: 'orderbook',
      symbol: symbol,
      bids: [[price_base(symbol) - 0.01, 100], [price_base(symbol) - 0.02, 50]],
      asks: [[price_base(symbol) + 0.01, 100], [price_base(symbol) + 0.02, 50]],
      ts: Time.now.utc.iso8601
    }
  end

  def quote_message(symbol)
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

  def price_base(symbol)
    # Simple deterministic base price per symbol for tests
    base = symbol.each_byte.sum % 200 + 50
    base.to_f
  end
end
