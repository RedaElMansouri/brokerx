# frozen_string_literal: true

# UC-01: Renvoyer l'email de vérification
class ResendVerificationUseCase
  Result = Struct.new(:success?, :errors, keyword_init: true)

  def execute(client_id:)
    client = Client.find(client_id)

    if client.verified?
      return Result.new(success?: false, errors: ['Email already verified'])
    end

    # Rate limiting - max 3 resends per hour
    recent_tokens = client.verification_tokens
                          .email_verification
                          .where('created_at > ?', 1.hour.ago)
                          .count

    if recent_tokens >= 3
      return Result.new(success?: false, errors: ['Too many requests. Please try again later.'])
    end

    # Create new verification token
    token = client.verification_tokens.create!(
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 24.hours.from_now,
      token_type: 'email_verification'
    )

    # Send email
    VerificationMailer.verification_email(client, token.token).deliver_later

    Result.new(success?: true, errors: [])
  rescue ActiveRecord::RecordNotFound
    Result.new(success?: false, errors: ['Client not found'])
  rescue StandardError => e
    Rails.logger.error("ResendVerificationUseCase error: #{e.message}")
    Result.new(success?: false, errors: [e.message])
  end
end
