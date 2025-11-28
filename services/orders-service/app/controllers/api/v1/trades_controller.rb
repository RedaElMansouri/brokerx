# frozen_string_literal: true

module Api
  module V1
    class TradesController < ApplicationController
      # GET /api/v1/trades
      def index
        trades = Trade.joins(:order)
                      .where(orders: { client_id: current_client_id })
                      .order(executed_at: :desc)
                      .limit(params[:limit] || 50)

        render json: {
          success: true,
          data: trades.map { |t| trade_json(t) },
          meta: { count: trades.count }
        }
      end

      # GET /api/v1/trades/:id
      def show
        trade = Trade.joins(:order)
                     .where(orders: { client_id: current_client_id })
                     .find(params[:id])

        render json: {
          success: true,
          **trade_json(trade)
        }
      end

      private

      def trade_json(trade)
        {
          id: trade.id,
          order_id: trade.order_id,
          symbol: trade.symbol,
          direction: trade.direction,
          quantity: trade.quantity,
          price: trade.price.to_f,
          total: trade.total.to_f,
          executed_at: trade.executed_at.iso8601,
          created_at: trade.created_at.iso8601
        }
      end
    end
  end
end
