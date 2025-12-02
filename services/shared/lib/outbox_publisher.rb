# frozen_string_literal: true

require_relative '../../shared/lib/event_bus'

# OutboxPublisher - Publishes pending OutboxEvents to Redis EventBus
# Implements the Transactional Outbox Pattern for reliable event publishing
#
# The outbox pattern ensures:
# 1. Events are created atomically with domain changes (same transaction)
# 2. Events are published asynchronously but reliably
# 3. If publishing fails, events are retried
# 4. Duplicate delivery is handled via idempotency
#
# Run with: rails outbox:publish (continuous) or as a background job
#
class OutboxPublisher
  BATCH_SIZE = 100
  POLL_INTERVAL = 1 # seconds

  def initialize
    @running = false
  end

  # Start the publisher (continuous mode)
  def start
    @running = true
    Rails.logger.info('[OutboxPublisher] Starting...')

    while @running
      published = publish_batch
      sleep(POLL_INTERVAL) if published.zero?
    end

    Rails.logger.info('[OutboxPublisher] Stopped')
  end

  def stop
    @running = false
  end

  # Publish a single batch of pending events
  # @return [Integer] Number of events published
  def publish_batch
    events = OutboxEvent.pending.limit(BATCH_SIZE).lock('FOR UPDATE SKIP LOCKED')
    
    return 0 if events.empty?

    published_count = 0

    events.each do |event|
      publish_event(event)
      published_count += 1
    rescue StandardError => e
      Rails.logger.error("[OutboxPublisher] Failed to publish event #{event.id}: #{e.message}")
      event.mark_failed!(e.message)
    end

    Rails.logger.info("[OutboxPublisher] Published #{published_count} events")
    published_count
  end

  private

  def publish_event(event)
    event.mark_processing!

    EventBus.publish(
      event.event_type,
      event.payload.deep_symbolize_keys,
      correlation_id: event.payload['correlation_id'] || event.payload['saga_id']
    )

    event.mark_processed!
  end
end
