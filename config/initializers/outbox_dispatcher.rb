# Start the OutboxDispatcher in non-test environments unless explicitly disabled
unless Rails.env.test? || ENV['OUTBOX_DISABLED'] == '1'
  begin
    Application::Services::OutboxDispatcher.instance.start!
  rescue StandardError => e
    Rails.logger.error("[OUTBOX] failed to start: #{e.message}")
  end
end
