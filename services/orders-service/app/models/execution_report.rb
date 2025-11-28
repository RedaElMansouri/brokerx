# frozen_string_literal: true

class ExecutionReport < ApplicationRecord
  belongs_to :order
  belongs_to :trade, optional: true

  validates :status, presence: true, inclusion: { in: %w[new working filled partially_filled cancelled rejected] }

  before_validation :set_defaults, on: :create

  scope :pending, -> { where(processed: false) }
  scope :processed, -> { where(processed: true) }

  def mark_processed!
    update!(processed: true, processed_at: Time.current)
  end

  private

  def set_defaults
    self.processed ||= false
  end
end
