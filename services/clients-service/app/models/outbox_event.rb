# frozen_string_literal: true

# Outbox Event for event-driven communication between microservices
class OutboxEvent < ApplicationRecord
  self.table_name = 'outbox_events'

  validates :aggregate_type, presence: true
  validates :aggregate_id, presence: true
  validates :event_type, presence: true
  validates :payload, presence: true

  scope :pending, -> { where(processed: false) }
  scope :processed, -> { where(processed: true) }

  def mark_as_processed!
    update!(processed: true, processed_at: Time.current)
  end
end
