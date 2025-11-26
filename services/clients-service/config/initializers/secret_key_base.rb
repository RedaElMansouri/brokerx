# frozen_string_literal: true

# Secret key base initializer
Rails.application.config.secret_key_base = ENV.fetch('SECRET_KEY_BASE') {
  # Generate a random key if not provided
  SecureRandom.hex(64)
}
