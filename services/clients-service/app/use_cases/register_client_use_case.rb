# frozen_string_literal: true

# UC-01: Inscription du Client
class RegisterClientUseCase
  Result = Struct.new(:success?, :client, :errors, keyword_init: true)

  def execute(params)
    client = Client.new(
      email: params[:email],
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      name: params[:name]
    )

    if client.save
      # Publish event for other services
      publish_client_registered_event(client)
      
      Result.new(success?: true, client: client, errors: [])
    else
      Result.new(success?: false, client: nil, errors: client.errors.full_messages)
    end
  rescue StandardError => e
    Rails.logger.error("RegisterClientUseCase error: #{e.message}")
    Result.new(success?: false, client: nil, errors: [e.message])
  end

  private

  def publish_client_registered_event(client)
    OutboxEvent.create!(
      aggregate_type: 'Client',
      aggregate_id: client.id,
      event_type: 'client.registered',
      payload: {
        client_id: client.id,
        email: client.email,
        name: client.name,
        registered_at: client.created_at.iso8601
      }
    )
  end
end
