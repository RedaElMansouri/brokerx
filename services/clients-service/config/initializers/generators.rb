# frozen_string_literal: true

# Enable UUID as primary key for PostgreSQL
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
