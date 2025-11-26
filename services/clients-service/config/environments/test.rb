# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV['CI'].present?
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.perform_caching = false
  config.action_controller.allow_forgery_protection = false

  # Active Record
  config.active_record.migration_error = :page_load

  # Mailer
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test

  # Active Job
  config.active_job.queue_adapter = :test
end
