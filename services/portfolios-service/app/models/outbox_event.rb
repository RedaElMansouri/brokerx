# frozen_string_literal: true

# Outbox Event model for transactional messaging pattern
class OutboxEvent < ApplicationRecord
  validates :aggregate_type, presence: true
  validates :aggregate_id, presence: true
  validates :event_type, presence: true
  validates :payload, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processed failed] }

  before_validation :set_defaults, on: :create

  scope :pending, -> { where(status: 'pending') }
  scope :failed, -> { where(status: 'failed') }
  scope :processable, -> { pending.order(created_at: :asc) }

  def mark_processed!
    update!(status: 'processed', processed_at: Time.current)
  end

  def mark_failed!(error_message = nil)
    increment!(:retry_count)
    update!(
      status: retry_count >= max_retries ? 'failed' : 'pending',
      last_error: error_message
    )
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.retry_count ||= 0
  end

  def max_retries
    5
  end
end
