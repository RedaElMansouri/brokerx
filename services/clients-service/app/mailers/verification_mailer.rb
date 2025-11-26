# frozen_string_literal: true

class VerificationMailer < ApplicationMailer
  def verification_email(client, token)
    @client = client
    @token = token
    @verification_url = "#{ENV.fetch('APP_URL', 'http://localhost:3001')}/api/v1/clients/#{client.id}/verify_email?token=#{token}"

    mail(
      to: client.email,
      subject: 'BrokerX - Verify your email address'
    )
  end
end
