# frozen_string_literal: true

class FundReservation < ApplicationRecord
  belongs_to :portfolio

  validates :order_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[reserved settled released] }

  scope :reserved, -> { where(status: 'reserved') }
  scope :settled, -> { where(status: 'settled') }
  scope :released, -> { where(status: 'released') }

  def reserved?
    status == 'reserved'
  end

  def settled?
    status == 'settled'
  end

  def released?
    status == 'released'
  end
end
