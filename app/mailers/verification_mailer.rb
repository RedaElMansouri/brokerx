class VerificationMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'no-reply@brokerx.local')

  def send_verification
    @token = params[:token]
    mail(to: params[:email], subject: 'Confirmez votre adresse e-mail')
  end
end
