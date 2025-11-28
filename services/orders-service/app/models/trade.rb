# frozen_string_literal: true

class Trade < ApplicationRecord
  belongs_to :order

  validates :symbol, presence: true
  validates :direction, presence: true, inclusion: { in: %w[buy sell] }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :executed_at, presence: true

  before_validation :set_defaults, on: :create

  def total
    quantity * price
  end

  private

  def set_defaults
    self.executed_at ||= Time.current
    self.symbol ||= order&.symbol
    self.direction ||= order&.direction
  end
end
