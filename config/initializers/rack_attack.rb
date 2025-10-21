class Rack::Attack
  # Throttle login attempts by IP
  throttle('req/ip', limit: (ENV.fetch('RACK_ATTACK_REQ_LIMIT', '300').to_i), period: 5.minutes) do |req|
    req.ip
  end

  # Specific throttles for auth endpoints
  throttle('auth/login/ip', limit: (ENV.fetch('RACK_ATTACK_LOGIN_LIMIT', '20').to_i), period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/v1/auth/login') && req.post?
  end

  throttle('auth/mfa/ip', limit: (ENV.fetch('RACK_ATTACK_MFA_LIMIT', '30').to_i), period: 10.minutes) do |req|
    req.ip if req.path.start_with?('/api/v1/auth/verify_mfa') && req.post?
  end

  # Throttle deposits to reduce abuse
  throttle('deposits/ip', limit: (ENV.fetch('RACK_ATTACK_DEPOSIT_LIMIT', '30').to_i), period: 10.minutes) do |req|
    req.ip if req.path.start_with?('/api/v1/deposits') && req.post?
  end

  # Allow known health endpoints without throttling
  safelist('healthcheck') do |req|
    ['/up', '/healthz', '/health'].include?(req.path)
  end
end

# Use Rack::Attack
Rails.application.config.middleware.use Rack::Attack
