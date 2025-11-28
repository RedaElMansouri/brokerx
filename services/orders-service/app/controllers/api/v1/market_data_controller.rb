# frozen_string_literal: true

module Api
  module V1
    # UC-04: Market Data (REST fallback)
    class MarketDataController < ApplicationController
      skip_before_action :authenticate_request!, only: [:index, :show]

      SYMBOLS = %w[AAPL MSFT GOOGL AMZN META TSLA NVDA].freeze

      # GET /api/v1/market_data
      def index
        data = SYMBOLS.map { |symbol| quote_for(symbol) }

        render json: {
          success: true,
          data: data,
          timestamp: Time.current.iso8601
        }
      end

      # GET /api/v1/market_data/:symbol
      def show
        symbol = params[:symbol].upcase
        
        unless SYMBOLS.include?(symbol)
          return render json: {
            success: false,
            error: "Symbol #{symbol} not found"
          }, status: :not_found
        end

        render json: {
          success: true,
          data: {
            quote: quote_for(symbol),
            orderbook: orderbook_for(symbol)
          },
          timestamp: Time.current.iso8601
        }
      end

      private

      def quote_for(symbol)
        # Simulated market data
        base_price = base_price_for(symbol)
        spread = base_price * 0.001

        {
          symbol: symbol,
          bid: (base_price - spread).round(2),
          ask: (base_price + spread).round(2),
          mid: base_price.round(2),
          last: base_price.round(2),
          volume: rand(1_000_000..10_000_000),
          change: (rand(-5.0..5.0)).round(2),
          change_percent: (rand(-3.0..3.0)).round(2),
          timestamp: Time.current.iso8601
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
          timestamp: Time.current.iso8601
        }
      end

      def base_price_for(symbol)
        prices = {
          'AAPL' => 175.0 + rand(-5.0..5.0),
          'MSFT' => 380.0 + rand(-10.0..10.0),
          'GOOGL' => 140.0 + rand(-5.0..5.0),
          'AMZN' => 185.0 + rand(-5.0..5.0),
          'META' => 500.0 + rand(-15.0..15.0),
          'TSLA' => 250.0 + rand(-10.0..10.0),
          'NVDA' => 480.0 + rand(-20.0..20.0)
        }
        prices[symbol] || 100.0
      end
    end
  end
end
