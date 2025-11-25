require 'test_helper'

class MatchingEngineTest < ActiveSupport::TestCase
  def setup
    @engine = Application::Services::MatchingEngine.instance
  end

  test 'order moves to working and execution.report created when no match' do
    account_id = create_client!(email: 'user1@example.test')
    order = Infrastructure::Persistence::ActiveRecord::OrderRecord.create!(
      account_id: account_id,
      symbol: 'AAPL',
      order_type: 'limit',
      direction: 'buy',
      quantity: 10,
      price: 100.0,
      time_in_force: 'DAY',
      status: 'new'
    )

    assert_equal 'new', order.status
    @engine.test_process(order_id: order.id, symbol: 'AAPL', direction: 'buy', order_type: 'limit', quantity: 10, price: 100.0)
    order.reload
    assert_equal 'working', order.status
    evt = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.where(event_type: 'execution.report', entity_id: order.id).last
    assert evt, 'expected execution.report event'
    assert_equal 'pending', evt.status
    assert_equal 'working', evt.payload['status']
  end

  test 'two opposing orders are matched and execution.report events created' do
    buyer_id = create_client!(email: 'buyer@example.test')
    seller_id = create_client!(email: 'seller@example.test')
    buy_order = Infrastructure::Persistence::ActiveRecord::OrderRecord.create!(
      account_id: buyer_id,
      symbol: 'MSFT',
      order_type: 'limit',
      direction: 'buy',
      quantity: 5,
      price: 50.0,
      time_in_force: 'DAY',
      status: 'new'
    )
    sell_order = Infrastructure::Persistence::ActiveRecord::OrderRecord.create!(
      account_id: seller_id,
      symbol: 'MSFT',
      order_type: 'limit',
      direction: 'sell',
      quantity: 5,
      price: 50.0,
      time_in_force: 'DAY',
      status: 'new'
    )

    @engine.test_process(order_id: buy_order.id, symbol: 'MSFT', direction: 'buy', order_type: 'limit', quantity: 5, price: 50.0)
    buy_order.reload
    sell_order.reload
    assert_equal 'filled', buy_order.status
    assert_equal 'filled', sell_order.status
    events = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.where(event_type: 'execution.report', entity_id: [buy_order.id, sell_order.id])
    assert_equal 2, events.count, 'expected two execution.report events'
    statuses = events.map { |e| e.payload['status'] }.uniq
    assert_equal ['filled'], statuses
  end

  test 'top-of-book broadcast updates after working order' do
    account_id = create_client!(email: 'user2@example.test')
    order = Infrastructure::Persistence::ActiveRecord::OrderRecord.create!(
      account_id: account_id,
      symbol: 'GOOG',
      order_type: 'limit',
      direction: 'buy',
      quantity: 1,
      price: 10.0,
      time_in_force: 'DAY',
      status: 'new'
    )
    # Stub ActionCable broadcast to capture message
    messages = []
    stubbed_server = Minitest::Mock.new
    stubbed_server.expect(:broadcast, true) do |channel, msg|
      messages << [channel, msg]
      channel == 'market:GOOG'
    end
    ActionCable.server = stubbed_server

    @engine.test_process(order_id: order.id, symbol: 'GOOG', direction: 'buy', order_type: 'limit', quantity: 1, price: 10.0)
    stubbed_server.verify
    top_msgs = messages.select { |_, m| m[:type] == 'top_of_book' }
    assert !top_msgs.empty?, 'expected top_of_book broadcast'
    bid = top_msgs.last[1][:bid]
    assert bid, 'expected bid in top_of_book'
    assert_equal 10.0, bid[:price]
  end

  private

  def create_client!(email:)
    Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: email,
      phone: '1234567890',
      first_name: 'Test',
      last_name: 'User',
      date_of_birth: Date.new(1990,1,1),
      status: 'verified'
    ).id
  end
end
