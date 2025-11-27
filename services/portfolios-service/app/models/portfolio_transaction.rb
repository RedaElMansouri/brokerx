# frozen_string_literal: true

class PortfolioTransaction < ApplicationRecord
  belongs_to :portfolio

  validates :transaction_type, presence: true, inclusion: { in: %w[deposit withdrawal buy sell dividend fee] }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[CAD USD EUR] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed cancelled] }
  validates :idempotency_key, presence: true, uniqueness: { scope: :portfolio_id }

  before_validation :set_defaults, on: :create

  scope :deposits, -> { where(transaction_type: 'deposit') }
  scope :withdrawals, -> { where(transaction_type: 'withdrawal') }
  scope :completed, -> { where(status: 'completed') }
  scope :pending, -> { where(status: 'pending') }

  def deposit?
    transaction_type == 'deposit'
  end

  def withdrawal?
    transaction_type == 'withdrawal'
  end

  def completed?
    status == 'completed'
  end

  def pending?
    status == 'pending'
  end

  def complete!
    update!(status: 'completed', processed_at: Time.current)
  end

  def fail!(reason = nil)
    update!(status: 'failed', failure_reason: reason)
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.currency ||= portfolio&.currency || 'CAD'
  end
end
