# frozen_string_literal: true

# UC-02: Vérification du code MFA
class VerifyMfaUseCase
  Result = Struct.new(:success?, :client, :jwt_token, :expires_at, :errors, keyword_init: true)

  def execute(session_token:, mfa_code:)
    session = Session.find_by(token: session_token, session_type: 'mfa_pending')

    unless session
      return Result.new(success?: false, client: nil, jwt_token: nil, expires_at: nil, errors: ['Invalid session'])
    end

    if session.expired?
      session.revoke!
      return Result.new(success?: false, client: nil, jwt_token: nil, expires_at: nil, errors: ['Session expired. Please login again.'])
    end

    client = session.client

    unless client.verify_mfa_code!(mfa_code)
      return Result.new(success?: false, client: nil, jwt_token: nil, expires_at: nil, errors: ['Invalid MFA code'])
    end

    # Revoke the pending session
    session.revoke!

    # Generate JWT token
    expires_at = 24.hours.from_now
    jwt_token = JwtService.encode(
      client_id: client.id,
      email: client.email,
      exp: expires_at.to_i
    )

    # Create authenticated session
    client.sessions.create!(
      expires_at: expires_at,
      session_type: 'authenticated',
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )

    # Publish login event
    publish_client_logged_in_event(client)

    Result.new(
      success?: true,
      client: client,
      jwt_token: jwt_token,
      expires_at: expires_at,
      errors: []
    )
  rescue StandardError => e
    Rails.logger.error("VerifyMfaUseCase error: #{e.message}")
    Result.new(success?: false, client: nil, jwt_token: nil, expires_at: nil, errors: ['MFA verification error'])
  end

  private

  def publish_client_logged_in_event(client)
    OutboxEvent.create!(
      aggregate_type: 'Client',
      aggregate_id: client.id,
      event_type: 'client.logged_in',
      payload: {
        client_id: client.id,
        logged_in_at: Time.current.iso8601
      }
    )
  end
end
