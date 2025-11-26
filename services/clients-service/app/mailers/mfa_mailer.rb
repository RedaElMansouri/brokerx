# frozen_string_literal: true

class MfaMailer < ApplicationMailer
  def mfa_code_email(client, code)
    @client = client
    @code = code

    mail(
      to: client.email,
      subject: 'BrokerX - Your MFA Code'
    )
  end
end
