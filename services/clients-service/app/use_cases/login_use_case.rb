# frozen_string_literal: true

# UC-02: Première étape de l'authentification MFA
class LoginUseCase
  Result = Struct.new(:success?, :session_token, :errors, keyword_init: true)

  def execute(email:, password:)
    client = Client.find_by(email: email.downcase.strip)

    unless client
      return Result.new(success?: false, session_token: nil, errors: ['Invalid credentials'])
    end

    if client.locked?
      return Result.new(success?: false, session_token: nil, errors: ['Account is locked. Please try again later.'])
    end

    unless client.verified?
      return Result.new(success?: false, session_token: nil, errors: ['Please verify your email first'])
    end

    unless client.authenticate(password)
      client.increment_failed_attempts!
      return Result.new(success?: false, session_token: nil, errors: ['Invalid credentials'])
    end

    # Reset failed attempts on successful password
    client.reset_failed_attempts!

    # Generate MFA code and send via email
    mfa_record = client.generate_mfa_code!
    MfaMailer.mfa_code_email(client, mfa_record.code).deliver_later

    # Create temporary session for MFA verification
    session = client.sessions.create!(
      expires_at: 5.minutes.from_now,
      session_type: 'mfa_pending'
    )

    Rails.logger.info("MFA code sent to #{client.email}: #{mfa_record.code}") if Rails.env.development?

    Result.new(success?: true, session_token: session.token, errors: [])
  rescue StandardError => e
    Rails.logger.error("LoginUseCase error: #{e.message}")
    Result.new(success?: false, session_token: nil, errors: ['Authentication error'])
  end
end
