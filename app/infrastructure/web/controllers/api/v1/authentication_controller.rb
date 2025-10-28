module Api
  module V1
    class AuthenticationController < ApplicationController
      # Step 1: verify credentials and send MFA code by email
      def login
        use_case = Application::UseCases::AuthenticateUserUseCase.new(client_repository)
        result = use_case.execute(params[:email].to_s.strip.downcase, params[:password])

        client = result[:client]

        # generate MFA code and persist on the client record
        mfa_code = rand.to_s[2..7] # 6-digit numeric

        # Update ActiveRecord client record directly
        record = ::Infrastructure::Persistence::ActiveRecord::ClientRecord.find(client.id)
        record.update(mfa_code: mfa_code, mfa_sent_at: Time.current, mfa_attempts: 0)

        # Send MFA mail (mailer must be configured with SMTP env vars)
        if Rails.env.development?
          Rails.logger.info("[DEV MFA] code for #{client.email.value}: #{mfa_code}")
        else
          MfaMailer.send_mfa_code(client.email.value, mfa_code).deliver_later
        end

        render json: { success: true, mfa_required: true, message: 'MFA code sent to your email' }
      rescue StandardError => e
        render_api_error(code: 'unauthorized', message: e.message, status: :unauthorized)
      end

      # Step 2: verify MFA code and return JWT
      def verify_mfa
        email = params[:email].to_s.strip.downcase
        code = params[:code].to_s.strip

  record = ::Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(email: email)
  return render_api_error(code: 'unauthorized', message: 'Invalid email or code', status: :unauthorized) unless record

        # throttle attempts and check code expiry (10 minutes)
        if record.last_mfa_attempt_at && record.last_mfa_attempt_at > 1.minute.ago && record.mfa_attempts >= 5
          return render_api_error(code: 'too_many_requests', message: 'Too many attempts. Try later.', status: :too_many_requests)
        end

        record.update_columns(mfa_attempts: (record.mfa_attempts || 0) + 1, last_mfa_attempt_at: Time.current)

        if record.mfa_code == code && record.mfa_sent_at && record.mfa_sent_at > 10.minutes.ago
          # clear MFA fields
          record.update(mfa_code: nil, mfa_sent_at: nil, mfa_attempts: 0, last_mfa_attempt_at: nil)

          # generate token
          token = Application::UseCases::AuthenticateUserUseCase.new(client_repository).send(:generate_jwt_token,
                                                                                             record.id)

          render json: { success: true, token: token }
        else
          render_api_error(code: 'unauthorized', message: 'Invalid or expired MFA code', status: :unauthorized)
        end
      rescue StandardError => e
        render_api_error(code: 'internal_error', message: e.message, status: :internal_server_error)
      end

      private

      def client_repository
        Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
      end
    end
  end
end
