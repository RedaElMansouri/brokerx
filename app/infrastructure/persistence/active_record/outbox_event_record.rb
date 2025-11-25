module Infrastructure
  module Persistence
    module ActiveRecord
      class OutboxEventRecord < ::ApplicationRecord
        self.table_name = 'outbox_events'

        STATUSES = %w[pending processing processed failed].freeze

        validates :event_type, presence: true
        validates :status, inclusion: { in: STATUSES }
        validates :payload, presence: true

        scope :pending, -> { where(status: 'pending') }
      end
    end
  end
end
