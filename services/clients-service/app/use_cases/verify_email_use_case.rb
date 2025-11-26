# frozen_string_literal: true

# UC-01: Vérification de l'email du Client
class VerifyEmailUseCase
  Result = Struct.new(:success?, :client, :errors, keyword_init: true)

  def execute(client_id:, token:)
    client = Client.find(client_id)
    verification_token = client.verification_tokens
                               .email_verification
                               .find_by(token: token)

    unless verification_token
      return Result.new(success?: false, client: nil, errors: ['Invalid verification token'])
    end

    unless verification_token.valid_token?
      return Result.new(success?: false, client: nil, errors: ['Token expired or already used'])
    end

    ActiveRecord::Base.transaction do
      verification_token.mark_as_used!
      client.verify_email!
    end

    # Publish event
    publish_client_verified_event(client)

    Result.new(success?: true, client: client, errors: [])
  rescue ActiveRecord::RecordNotFound
    Result.new(success?: false, client: nil, errors: ['Client not found'])
  rescue StandardError => e
    Rails.logger.error("VerifyEmailUseCase error: #{e.message}")
    Result.new(success?: false, client: nil, errors: [e.message])
  end

  private

  def publish_client_verified_event(client)
    OutboxEvent.create!(
      aggregate_type: 'Client',
      aggregate_id: client.id,
      event_type: 'client.email_verified',
      payload: {
        client_id: client.id,
        email: client.email,
        verified_at: client.email_verified_at.iso8601
      }
    )
  end
end
