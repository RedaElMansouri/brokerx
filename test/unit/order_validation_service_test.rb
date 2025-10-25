require 'test_helper'

class OrderValidationServiceTest < ActiveSupport::TestCase
  def setup
    @repo = Infrastructure::Persistence::Repositories::ActiveRecordPortfolioRepository.new
  end

  test 'rejects negative quantity' do
    dto = Application::Dtos::PlaceOrderDto.new(account_id: 1, symbol: 'AAPL', order_type: 'market', direction: 'buy',
                                               quantity: 0, price: nil, time_in_force: 'DAY')
    errors = Application::Services::OrderValidationService.new(@repo).validate_pre_trade(dto, 1)
    assert_includes errors, 'Quantity must be positive'
  end

  test 'rejects price outside band for limit' do
    dto = Application::Dtos::PlaceOrderDto.new(account_id: 1, symbol: 'AAPL', order_type: 'limit', direction: 'buy',
                                               quantity: 1, price: 0.5, time_in_force: 'DAY')
    errors = Application::Services::OrderValidationService.new(@repo).validate_pre_trade(dto, 1)
    assert_includes errors, 'Price outside valid trading band'
  end
end
