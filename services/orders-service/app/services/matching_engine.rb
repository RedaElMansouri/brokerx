# frozen_string_literal: true

require 'singleton'
require 'concurrent'

# UC-07: Order Matching Engine
# In-memory matching engine for order book management
class MatchingEngine
  include Singleton

  def initialize
    @order_books = Concurrent::Hash.new { |h, k| h[k] = OrderBook.new(k) }
    @queue = Queue.new
    @running = false
    @worker = nil
  end

  def start
    return if @running

    @running = true
    @worker = Thread.new { process_queue }
    Rails.logger.info('[MATCHING] Engine started')
  end

  def stop
    @running = false
    @queue.close
    @worker&.join(5)
    Rails.logger.info('[MATCHING] Engine stopped')
  end

  def running?
    @running
  end

  def enqueue_order(order)
    return unless @running

    @queue << order
    Rails.logger.info("[MATCHING] Order #{order.id} enqueued for #{order.symbol}")
  end

  def remove_order(order_id)
    @order_books.each_value { |book| book.remove_order(order_id) }
    Rails.logger.info("[MATCHING] Order #{order_id} removed from books")
  end

  def order_book_for(symbol)
    @order_books[symbol.upcase]
  end

  def queue_size
    @queue.size
  end

  private

  def process_queue
    while @running
      begin
        order = @queue.pop(true) rescue nil
        next unless order

        process_order(order)
      rescue StandardError => e
        Rails.logger.error("[MATCHING] Error processing order: #{e.message}")
      end
    end
  end

  def process_order(order)
    book = @order_books[order.symbol]
    matches = book.match(order)

    if matches.empty?
      # No match - order goes to working status
      mark_order_working(order)
    else
      # Process matches
      matches.each { |match| execute_trade(match) }
    end
  end

  def mark_order_working(order)
    order.update!(status: 'working')

    # Create execution report
    ExecutionReport.create!(
      order: order,
      status: 'working',
      quantity: order.quantity,
      price: order.price
    )

    # Create outbox event
    OutboxEvent.create!(
      aggregate_type: 'Order',
      aggregate_id: order.id,
      event_type: 'execution.report',
      payload: {
        order_id: order.id,
        client_id: order.client_id,
        status: 'working',
        symbol: order.symbol,
        quantity: order.quantity,
        price: order.price,
        timestamp: Time.current.iso8601
      }
    )

    # Broadcast via ActionCable
    broadcast_order_update(order, 'working')

    Rails.logger.info("[MATCHING] Order #{order.id} marked as working")
  end

  def execute_trade(match)
    buy_order = match[:buy_order]
    sell_order = match[:sell_order]
    quantity = match[:quantity]
    price = match[:price]

    ActiveRecord::Base.transaction do
      # Create trade records
      buy_trade = Trade.create!(
        order: buy_order,
        symbol: buy_order.symbol,
        direction: 'buy',
        quantity: quantity,
        price: price,
        counterparty_order_id: sell_order.id,
        executed_at: Time.current
      )

      sell_trade = Trade.create!(
        order: sell_order,
        symbol: sell_order.symbol,
        direction: 'sell',
        quantity: quantity,
        price: price,
        counterparty_order_id: buy_order.id,
        executed_at: Time.current
      )

      # Update orders
      buy_order.fill!(quantity, price)
      sell_order.fill!(quantity, price)

      # Create execution reports
      create_fill_report(buy_order, buy_trade)
      create_fill_report(sell_order, sell_trade)

      Rails.logger.info("[MATCHING] Trade executed: #{quantity} @ #{price} between #{buy_order.id} and #{sell_order.id}")
    end
  end

  def create_fill_report(order, trade)
    status = order.status == 'filled' ? 'filled' : 'partially_filled'

    ExecutionReport.create!(
      order: order,
      trade: trade,
      status: status,
      quantity: trade.quantity,
      price: trade.price
    )

    OutboxEvent.create!(
      aggregate_type: 'Order',
      aggregate_id: order.id,
      event_type: 'execution.report',
      payload: {
        order_id: order.id,
        client_id: order.client_id,
        trade_id: trade.id,
        status: status,
        symbol: order.symbol,
        quantity: trade.quantity,
        price: trade.price.to_f,
        filled_quantity: order.filled_quantity,
        remaining_quantity: order.remaining_quantity,
        timestamp: Time.current.iso8601
      }
    )

    broadcast_order_update(order, status, trade)
  end

  def broadcast_order_update(order, status, trade = nil)
    payload = {
      type: 'order_update',
      order_id: order.id,
      status: status,
      symbol: order.symbol,
      timestamp: Time.current.iso8601
    }

    if trade
      payload[:trade] = {
        id: trade.id,
        quantity: trade.quantity,
        price: trade.price.to_f
      }
    end

    ActionCable.server.broadcast("orders_#{order.client_id}", payload)
  rescue StandardError => e
    Rails.logger.warn("[MATCHING] Failed to broadcast: #{e.message}")
  end
end

# Inner class for managing order book per symbol
class OrderBook
  def initialize(symbol)
    @symbol = symbol
    @bids = [] # Buy orders sorted by price (highest first)
    @asks = [] # Sell orders sorted by price (lowest first)
    @mutex = Mutex.new
  end

  def match(order)
    @mutex.synchronize do
      if order.buy?
        match_buy(order)
      else
        match_sell(order)
      end
    end
  end

  def remove_order(order_id)
    @mutex.synchronize do
      @bids.reject! { |o| o.id == order_id }
      @asks.reject! { |o| o.id == order_id }
    end
  end

  def bids
    @mutex.synchronize { @bids.dup }
  end

  def asks
    @mutex.synchronize { @asks.dup }
  end

  private

  def match_buy(buy_order)
    matches = []
    remaining = buy_order.quantity

    while remaining > 0 && @asks.any?
      best_ask = @asks.first

      # Check price compatibility for limit orders
      if buy_order.limit_order? && best_ask.price > buy_order.price
        break
      end

      # Calculate match quantity
      match_qty = [remaining, best_ask.remaining_quantity].min
      match_price = best_ask.price

      matches << {
        buy_order: buy_order,
        sell_order: best_ask,
        quantity: match_qty,
        price: match_price
      }

      remaining -= match_qty

      # Remove fully filled ask
      @asks.shift if best_ask.remaining_quantity <= match_qty
    end

    # Add remaining buy order to book if not fully filled
    if remaining > 0 && buy_order.limit_order?
      insert_bid(buy_order)
    end

    matches
  end

  def match_sell(sell_order)
    matches = []
    remaining = sell_order.quantity

    while remaining > 0 && @bids.any?
      best_bid = @bids.first

      # Check price compatibility for limit orders
      if sell_order.limit_order? && best_bid.price < sell_order.price
        break
      end

      # Calculate match quantity
      match_qty = [remaining, best_bid.remaining_quantity].min
      match_price = best_bid.price

      matches << {
        buy_order: best_bid,
        sell_order: sell_order,
        quantity: match_qty,
        price: match_price
      }

      remaining -= match_qty

      # Remove fully filled bid
      @bids.shift if best_bid.remaining_quantity <= match_qty
    end

    # Add remaining sell order to book if not fully filled
    if remaining > 0 && sell_order.limit_order?
      insert_ask(sell_order)
    end

    matches
  end

  def insert_bid(order)
    index = @bids.bsearch_index { |o| o.price < order.price } || @bids.size
    @bids.insert(index, order)
  end

  def insert_ask(order)
    index = @asks.bsearch_index { |o| o.price > order.price } || @asks.size
    @asks.insert(index, order)
  end
end
