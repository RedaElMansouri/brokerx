# frozen_string_literal: true

class ClientSerializer
  def initialize(client)
    @client = client
  end

  def as_json
    {
      id: @client.id,
      email: @client.email,
      name: @client.name,
      email_verified: @client.email_verified,
      mfa_enabled: @client.mfa_enabled,
      created_at: @client.created_at.iso8601,
      updated_at: @client.updated_at.iso8601
    }
  end
end
