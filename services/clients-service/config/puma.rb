# frozen_string_literal: true

# Puma configuration for Clients Service

# Workers for multi-process mode (production only)
# On macOS development, workers cause fork issues
if ENV.fetch('RAILS_ENV', 'development') == 'production'
  workers ENV.fetch('WEB_CONCURRENCY', 2).to_i
else
  workers 0  # Single mode for development
end

# Threads for each worker
max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }.to_i
threads min_threads_count, max_threads_count

# Bind to port
port ENV.fetch('PORT', 3000)

# Environment
environment ENV.fetch('RAILS_ENV', 'development')

# Allow puma to be restarted
plugin :tmp_restart

# Preload app for better memory efficiency (production only)
if ENV.fetch('RAILS_ENV', 'development') == 'production'
  preload_app!

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
end
