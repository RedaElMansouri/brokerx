# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class TradingSagaTest < ActiveSupport::TestCase
  setup do
    @client = Infrastructure::Persistence::ActiveRecord::ClientRecord.create!(
      first_name: 'Saga',
      last_name: 'Test',
      email: "saga_test_#{SecureRandom.hex(4)}@example.com",
      password_digest: BCrypt::Password.create('password123'),
      date_of_birth: Date.new(1990, 1, 1),
      status: 'active'
    )

    @portfolio = Infrastructure::Persistence::ActiveRecord::PortfolioRecord.create!(
      account_id: @client.id,
      available_balance: 10_000.0,
      reserved_balance: 0.0,
      currency: 'USD'
    )

    @order_repo = Infrastructure::Persistence::Repositories::ActiveRecordOrderRepository.new
    @portfolio_repo = Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new

    # Mock matching engine that does nothing
    @mock_matching_engine = Minitest::Mock.new
    @mock_matching_engine.expect(:enqueue_order, true, [Hash])
  end

  test 'successful saga execution for buy order' do
    dto = Application::Dtos::PlaceOrderDto.new(
      account_id: @client.id,
      symbol: 'AAPL',
      order_type: 'limit',
      direction: 'buy',
      quantity: 10,
      price: 150.0,
      time_in_force: 'DAY'
    )

    saga = Application::Services::TradingSaga.new(
      order_repo: @order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: @mock_matching_engine
    )

    result = saga.execute(dto: dto, client_id: @client.id)

    assert result.success, "Saga should succeed, got error: #{result.error}"
    assert_not_nil result.order_id
    assert_equal 4, result.steps_completed.size
    assert_includes result.steps_completed, :validate_order
    assert_includes result.steps_completed, :reserve_funds
    assert_includes result.steps_completed, :create_order
    assert_includes result.steps_completed, :submit_to_matching
    assert_not result.compensated

    # Verify order was created
    order = Infrastructure::Persistence::ActiveRecord::OrderRecord.find(result.order_id)
    assert_equal 'new', order.status
    assert_equal 'AAPL', order.symbol
    assert_equal 10, order.quantity

    # Verify funds were reserved
    @portfolio.reload
    assert_equal 8500.0, @portfolio.available_balance # 10000 - (10 * 150)
    assert_equal 1500.0, @portfolio.reserved_balance

    # Verify outbox events were created
    saga_events = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.where(
      "payload->>'saga_id' = ?", saga.saga_id
    )
    assert saga_events.exists?, 'Saga events should be created in outbox'

    @mock_matching_engine.verify
  end

  test 'successful saga for sell order (no funds reservation)' do
    dto = Application::Dtos::PlaceOrderDto.new(
      account_id: @client.id,
      symbol: 'AAPL',
      order_type: 'market',
      direction: 'sell',
      quantity: 5,
      price: nil,
      time_in_force: 'DAY'
    )

    saga = Application::Services::TradingSaga.new(
      order_repo: @order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: @mock_matching_engine
    )

    result = saga.execute(dto: dto, client_id: @client.id)

    assert result.success
    assert_not_nil result.order_id

    # No funds should be reserved for sell orders
    @portfolio.reload
    assert_equal 10_000.0, @portfolio.available_balance
    assert_equal 0.0, @portfolio.reserved_balance

    @mock_matching_engine.verify
  end

  test 'saga compensates when funds reservation fails' do
    # Set balance too low
    @portfolio.update!(available_balance: 100.0)

    dto = Application::Dtos::PlaceOrderDto.new(
      account_id: @client.id,
      symbol: 'AAPL',
      order_type: 'limit',
      direction: 'buy',
      quantity: 10,
      price: 150.0, # Cost: 1500, but only 100 available
      time_in_force: 'DAY'
    )

    # Don't expect matching engine call since we'll fail before that
    saga = Application::Services::TradingSaga.new(
      order_repo: @order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: Application::Services::MatchingEngine.instance
    )

    result = saga.execute(dto: dto, client_id: @client.id)

    # Should fail at validation step (insufficient funds check)
    assert_not result.success
    assert_includes result.error.to_s.downcase, 'insufficient'
  end

  test 'saga compensates on order creation failure' do
    dto = Application::Dtos::PlaceOrderDto.new(
      account_id: @client.id,
      symbol: 'AAPL',
      order_type: 'limit',
      direction: 'buy',
      quantity: 10,
      price: 150.0,
      time_in_force: 'DAY'
    )

    # Create a mock repo that fails on create
    failing_order_repo = Minitest::Mock.new
    failing_order_repo.expect(:create, nil) do |_attrs|
      raise StandardError, 'Database connection lost'
    end

    saga = Application::Services::TradingSaga.new(
      order_repo: failing_order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: @mock_matching_engine
    )

    result = saga.execute(dto: dto, client_id: @client.id)

    assert_not result.success
    assert result.compensated
    assert_includes result.error, 'Database connection lost'
    assert_includes result.steps_completed, :validate_order
    assert_includes result.steps_completed, :reserve_funds
    assert_not_includes result.steps_completed, :create_order

    # Funds should be released after compensation
    @portfolio.reload
    assert_equal 10_000.0, @portfolio.available_balance
    assert_equal 0.0, @portfolio.reserved_balance
  end

  test 'saga tracks correlation id' do
    dto = Application::Dtos::PlaceOrderDto.new(
      account_id: @client.id,
      symbol: 'AAPL',
      order_type: 'limit',
      direction: 'buy',
      quantity: 1,
      price: 100.0,
      time_in_force: 'DAY'
    )

    correlation_id = 'test-correlation-123'

    saga = Application::Services::TradingSaga.new(
      order_repo: @order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: @mock_matching_engine
    )

    result = saga.execute(dto: dto, client_id: @client.id, correlation_id: correlation_id)

    assert result.success

    # Check that outbox events have the correlation ID
    events = Infrastructure::Persistence::ActiveRecord::OutboxEventRecord.where(correlation_id: correlation_id)
    assert events.exists?, 'Events should have correlation_id'

    @mock_matching_engine.verify
  end

  test 'saga generates unique saga_id' do
    dto = Application::Dtos::PlaceOrderDto.new(
      account_id: @client.id,
      symbol: 'AAPL',
      order_type: 'limit',
      direction: 'buy',
      quantity: 1,
      price: 100.0,
      time_in_force: 'DAY'
    )

    saga1 = Application::Services::TradingSaga.new(
      order_repo: @order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: @mock_matching_engine
    )

    # Need another mock for second saga
    mock2 = Minitest::Mock.new
    mock2.expect(:enqueue_order, true, [Hash])

    saga2 = Application::Services::TradingSaga.new(
      order_repo: @order_repo,
      portfolio_repo: @portfolio_repo,
      matching_engine: mock2
    )

    result1 = saga1.execute(dto: dto, client_id: @client.id)
    result2 = saga2.execute(dto: dto, client_id: @client.id)

    assert_not_equal result1.saga_id, result2.saga_id
    assert_not_nil result1.saga_id
    assert_not_nil result2.saga_id

    @mock_matching_engine.verify
    mock2.verify
  end
end
