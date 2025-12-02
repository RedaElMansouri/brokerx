# frozen_string_literal: true

class Order < ApplicationRecord
  has_many :trades, dependent: :destroy
  has_many :execution_reports, dependent: :destroy

  # Validations
  validates :client_id, presence: true
  validates :symbol, presence: true, format: { with: /\A[A-Z]{1,5}\z/, message: 'must be 1-5 uppercase letters' }
  validates :direction, presence: true, inclusion: { in: %w[buy sell] }
  validates :order_type, presence: true, inclusion: { in: %w[market limit] }
  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :price, numericality: { greater_than: 0 }, if: :limit_order?
  validates :time_in_force, presence: true, inclusion: { in: %w[DAY GTC IOC FOK] }
  validates :status, presence: true, inclusion: { in: %w[new pending_funds working filled partially_filled cancelled rejected] }

  # Scopes
  scope :active, -> { where(status: %w[new working partially_filled]) }
  scope :for_client, ->(client_id) { where(client_id: client_id) }
  scope :for_symbol, ->(symbol) { where(symbol: symbol.upcase) }
  scope :buys, -> { where(direction: 'buy') }
  scope :sells, -> { where(direction: 'sell') }

  before_validation :normalize_symbol
  before_validation :set_defaults, on: :create

  def limit_order?
    order_type == 'limit'
  end

  def market_order?
    order_type == 'market'
  end

  def buy?
    direction == 'buy'
  end

  def sell?
    direction == 'sell'
  end

  def active?
    %w[new working partially_filled].include?(status)
  end

  def can_modify?
    active?
  end

  def can_cancel?
    active?
  end

  def fill!(quantity_filled, _fill_price)
    self.filled_quantity += quantity_filled
    
    if filled_quantity >= quantity
      self.status = 'filled'
    else
      self.status = 'partially_filled'
    end
    
    save!
  end

  def remaining_quantity
    quantity - filled_quantity
  end

  def total_value
    if limit_order?
      quantity * price
    else
      # For market orders, use a default price
      quantity * 100.0
    end
  end

  private

  def normalize_symbol
    self.symbol = symbol&.upcase&.strip
  end

  def set_defaults
    self.status ||= 'new'
    self.filled_quantity ||= 0
    self.time_in_force ||= 'DAY'
  end
end
