# frozen_string_literal: true

class RefreshTokenUseCase
  Result = Struct.new(:success?, :jwt_token, :expires_at, :errors, keyword_init: true)

  def execute(refresh_token:)
    decoded = JwtService.decode(refresh_token)
    
    unless decoded
      return Result.new(success?: false, jwt_token: nil, expires_at: nil, errors: ['Invalid token'])
    end

    client = Client.find_by(id: decoded[:client_id])
    
    unless client
      return Result.new(success?: false, jwt_token: nil, expires_at: nil, errors: ['Client not found'])
    end

    expires_at = 24.hours.from_now
    jwt_token = JwtService.encode(
      client_id: client.id,
      email: client.email,
      exp: expires_at.to_i
    )

    Result.new(
      success?: true,
      jwt_token: jwt_token,
      expires_at: expires_at,
      errors: []
    )
  rescue StandardError => e
    Rails.logger.error("RefreshTokenUseCase error: #{e.message}")
    Result.new(success?: false, jwt_token: nil, expires_at: nil, errors: ['Token refresh error'])
  end
end
