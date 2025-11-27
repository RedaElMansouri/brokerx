# frozen_string_literal: true

class Portfolio < ApplicationRecord
  has_many :portfolio_transactions, dependent: :destroy

  validates :client_id, presence: true
  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: %w[CAD USD EUR] }
  validates :cash_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[active suspended closed] }

  before_validation :set_defaults, on: :create

  scope :active, -> { where(status: 'active') }
  scope :for_client, ->(client_id) { where(client_id: client_id) }

  def deposit!(amount, idempotency_key:, currency: nil)
    raise ArgumentError, 'Amount must be positive' if amount <= 0

    transaction do
      # Check for existing transaction with same idempotency key
      existing = portfolio_transactions.find_by(idempotency_key: idempotency_key)
      if existing
        return { success: true, transaction: existing, already_processed: true }
      end

      # Create new deposit transaction
      tx = portfolio_transactions.create!(
        transaction_type: 'deposit',
        amount: amount,
        currency: currency || self.currency,
        status: 'completed',
        idempotency_key: idempotency_key,
        processed_at: Time.current
      )

      # Update balance
      update!(cash_balance: cash_balance + amount)

      { success: true, transaction: tx, already_processed: false }
    end
  end

  def withdraw!(amount, idempotency_key:, currency: nil)
    raise ArgumentError, 'Amount must be positive' if amount <= 0
    raise ArgumentError, 'Insufficient funds' if amount > cash_balance

    transaction do
      # Check for existing transaction with same idempotency key
      existing = portfolio_transactions.find_by(idempotency_key: idempotency_key)
      if existing
        return { success: true, transaction: existing, already_processed: true }
      end

      # Create new withdrawal transaction
      tx = portfolio_transactions.create!(
        transaction_type: 'withdrawal',
        amount: amount,
        currency: currency || self.currency,
        status: 'completed',
        idempotency_key: idempotency_key,
        processed_at: Time.current
      )

      # Update balance
      update!(cash_balance: cash_balance - amount)

      { success: true, transaction: tx, already_processed: false }
    end
  end

  private

  def set_defaults
    self.currency ||= 'CAD'
    self.cash_balance ||= 0.0
    self.status ||= 'active'
  end
end
