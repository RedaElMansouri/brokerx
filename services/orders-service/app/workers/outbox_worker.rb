# frozen_string_literal: true

# OutboxWorker - Background job that continuously publishes outbox events
# Uses Sidekiq for reliable background processing
#
# Schedule this to run periodically or use a scheduler like sidekiq-scheduler
#
class OutboxWorker
  include Sidekiq::Job

  sidekiq_options queue: :outbox, retry: 3

  def perform
    publisher = OutboxPublisher.new
    publisher.publish_batch
  end
end
