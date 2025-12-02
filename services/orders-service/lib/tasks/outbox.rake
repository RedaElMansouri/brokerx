# frozen_string_literal: true

namespace :outbox do
  desc 'Publish pending outbox events to EventBus (continuous)'
  task publish: :environment do
    publisher = OutboxPublisher.new

    # Handle graceful shutdown
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        puts "\nShutting down outbox publisher..."
        publisher.stop
      end
    end

    puts "Starting outbox publisher..."
    publisher.start
  end

  desc 'Publish a single batch of outbox events'
  task publish_batch: :environment do
    publisher = OutboxPublisher.new
    count = publisher.publish_batch
    puts "Published #{count} events"
  end

  desc 'Show outbox statistics'
  task stats: :environment do
    pending = OutboxEvent.pending.count
    processing = OutboxEvent.where(status: 'processing').count
    processed = OutboxEvent.where(status: 'processed').count
    failed = OutboxEvent.failed.count

    puts "Outbox Statistics"
    puts "-" * 30
    puts "Pending:    #{pending}"
    puts "Processing: #{processing}"
    puts "Processed:  #{processed}"
    puts "Failed:     #{failed}"
    puts "-" * 30
    puts "Total:      #{pending + processing + processed + failed}"
  end

  desc 'Retry failed outbox events'
  task retry_failed: :environment do
    failed_events = OutboxEvent.failed
    count = failed_events.count
    
    failed_events.update_all(status: 'pending', retry_count: 0)
    puts "Reset #{count} failed events to pending"
  end
end
