# frozen_string_literal: true

require 'jwt'

class JwtService
  ALGORITHM = 'HS256'

  class << self
    def encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      payload[:iat] = Time.current.to_i
      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret_key, true, { algorithm: ALGORITHM })
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      raise JWT::DecodeError, 'Token has expired'
    rescue JWT::DecodeError => e
      raise JWT::DecodeError, "Invalid token: #{e.message}"
    end

    def valid?(token)
      decode(token)
      true
    rescue JWT::DecodeError
      false
    end

    private

    def secret_key
      ENV.fetch('JWT_SECRET', 'microservices_jwt_secret_change_in_production')
    end
  end
end
