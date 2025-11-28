# frozen_string_literal: true

workers ENV.fetch('WEB_CONCURRENCY', 2).to_i

max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }.to_i
threads min_threads_count, max_threads_count

port ENV.fetch('PORT', 3000)

environment ENV.fetch('RAILS_ENV', 'development')

plugin :tmp_restart

preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
