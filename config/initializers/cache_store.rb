# Configure Rails cache store to use Redis when REDIS_URL is provided.

redis_url = ENV['REDIS_URL']

if redis_url && !redis_url.empty?
  Rails.logger.info("[Cache] Using Redis cache store at #{redis_url}")
  Rails.application.config.cache_store = :redis_cache_store, {
    url: redis_url,
    error_handler: ->(method:, _returning:, exception:) {
      Rails.logger.warn("RedisCacheStore error in #{method}: #{exception.class}: #{exception.message}")
    }
  }

  # Ensure controller-level caching is enabled when Redis is present
  Rails.application.config.action_controller.perform_caching = true
else
  Rails.logger.info('[Cache] Using default cache store (no REDIS_URL)')
end
