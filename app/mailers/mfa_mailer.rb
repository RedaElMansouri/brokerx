class MfaMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'no-reply@brokerx.local')

  def send_mfa_code(email, code)
    @code = code
    mail(to: email, subject: 'Votre code de vérification (MFA)')
  end
end
