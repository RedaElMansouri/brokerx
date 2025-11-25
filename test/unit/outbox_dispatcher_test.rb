require 'test_helper'

class OutboxDispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @dispatcher = Application::Services::OutboxDispatcher.instance
  end

  test 'execution.report event is processed: status -> processed, broadcast + mail enqueued' do
    client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      email: 'notify@example.test', phone: '123', first_name: 'Exec', last_name: 'Report',
      date_of_birth: Date.new(1990,1,1), status: 'verified'
    )
    order = Infrastructure::Persistence::ActiveRecord::OrderRecord.create!(
      account_id: client.id, symbol: 'AAPL', order_type: 'limit', direction: 'buy',
      quantity: 5, price: 100.0, time_in_force: 'DAY', status: 'filled'
    )

    evt = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.create!(
      event_type: 'execution.report', status: 'pending', entity_type: 'Order', entity_id: order.id,
      payload: { order_id: order.id, status: 'filled', quantity: 5, price: 100.0 }
    )

    messages = []
    stubbed_server = Minitest::Mock.new
    stubbed_server.expect(:broadcast, true) do |channel, msg|
      messages << [channel, msg]
      channel == "orders_status:#{order.id}" && msg[:type] == 'execution.report'
    end
    ActionCable.server = stubbed_server

    assert_enqueued_jobs 1 do
      @dispatcher.dispatch_pending
    end

    stubbed_server.verify

    evt.reload
    assert_equal 'processed', evt.status, 'event should be marked processed'
    broadcast = messages.last
    assert broadcast, 'expected a broadcast message'
    assert_equal 'execution.report', broadcast[1][:type]
    assert_equal 'filled', broadcast[1][:status]
  end
end
