# frozen_string_literal: true

class LogoutUseCase
  Result = Struct.new(:success?, :errors, keyword_init: true)

  def execute(client:)
    # Revoke all active sessions
    client.sessions.active.update_all(revoked: true, revoked_at: Time.current)

    Result.new(success?: true, errors: [])
  rescue StandardError => e
    Rails.logger.error("LogoutUseCase error: #{e.message}")
    Result.new(success?: false, errors: [e.message])
  end
end
