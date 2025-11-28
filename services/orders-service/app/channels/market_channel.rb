# frozen_string_literal: true

# UC-04: Market Data Channel (WebSocket)
# Provides real-time market data via ActionCable
class MarketChannel < ApplicationCable::Channel
  VALID_SYMBOLS = %w[AAPL MSFT GOOGL AMZN META TSLA NVDA].freeze
  VALID_MODES = %w[normal throttled].freeze

  def subscribed
    @symbols = parse_symbols
    @mode = parse_mode

    if @symbols.empty?
      reject
      return
    end

    @symbols.each do |symbol|
      stream_from "market_#{symbol}"
    end

    # Send initial snapshot
    send_snapshot

    Rails.logger.info("[MARKET] Client subscribed to #{@symbols.join(', ')} (mode: #{@mode})")
  end

  def unsubscribed
    Rails.logger.info("[MARKET] Client unsubscribed")
  end

  private

  def parse_symbols
    symbols = params['symbols'] || ['AAPL']
    symbols = [symbols] unless symbols.is_a?(Array)
    symbols.map(&:upcase).select { |s| VALID_SYMBOLS.include?(s) }
  end

  def parse_mode
    mode = params['mode'] || 'normal'
    VALID_MODES.include?(mode) ? mode : 'normal'
  end

  def send_snapshot
    @symbols.each do |symbol|
      transmit({
        type: 'quote',
        **quote_for(symbol)
      })

      transmit({
        type: 'orderbook',
        **orderbook_for(symbol)
      })
    end

    transmit({
      type: 'status',
      level: 'ok'
    })
  end

  def quote_for(symbol)
    base_price = base_price_for(symbol)
    spread = base_price * 0.001

    {
      symbol: symbol,
      bid: (base_price - spread).round(2),
      ask: (base_price + spread).round(2),
      mid: base_price.round(2),
      ts: Time.current.iso8601
    }
  end

  def orderbook_for(symbol)
    base_price = base_price_for(symbol)

    bids = 5.times.map do |i|
      [(base_price - (i + 1) * 0.05).round(2), rand(100..1000)]
    end

    asks = 5.times.map do |i|
      [(base_price + (i + 1) * 0.05).round(2), rand(100..1000)]
    end

    {
      symbol: symbol,
      bids: bids,
      asks: asks,
      ts: Time.current.iso8601
    }
  end

  def base_price_for(symbol)
    prices = {
      'AAPL' => 175.0,
      'MSFT' => 380.0,
      'GOOGL' => 140.0,
      'AMZN' => 185.0,
      'META' => 500.0,
      'TSLA' => 250.0,
      'NVDA' => 480.0
    }
    prices[symbol] || 100.0
  end
end
