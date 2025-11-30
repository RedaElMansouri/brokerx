# frozen_string_literal: true

# Record application boot time for uptime metrics
Rails.application.config.boot_time = Time.current
Rails.logger.info("[BOOT] Application boot time recorded: #{Rails.application.config.boot_time}")
