# frozen_string_literal: true

Rails.application.config.secret_key_base = ENV.fetch('SECRET_KEY_BASE') do
  # Development/test fallback
  'dev_secret_key_base_portfolios_service_change_in_production_1234567890abcdef'
end
