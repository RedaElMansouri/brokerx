module Dtos
  class PlaceOrderDto
      attr_reader :account_id, :symbol, :order_type, :direction, :quantity, :price, :time_in_force

      def initialize(account_id:, symbol:, order_type:, direction:, quantity:, price: nil, time_in_force: 'DAY')
        @account_id = account_id
        @symbol = symbol
        @order_type = order_type
        @direction = direction
        @quantity = quantity
        @price = price
        @time_in_force = time_in_force
      end

      def to_h
        {
          account_id: account_id,
          symbol: symbol,
          order_type: order_type,
          direction: direction,
          quantity: quantity,
          price: price,
          time_in_force: time_in_force
        }
      end
  end
end
