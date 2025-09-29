module Api
  module V1
    class AuthenticationController < ApplicationController
      # Step 1: verify credentials and send MFA code by email
      def login
        load_dependencies

        use_case = Application::UseCases::AuthenticateUserUseCase.new(client_repository)
        result = use_case.execute(params[:email].to_s.strip.downcase, params[:password])

        client = result[:client]

        # generate MFA code and persist on the client record
        mfa_code = rand.to_s[2..7] # 6-digit numeric

        # Update ActiveRecord client record directly
        record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find(client.id)
        record.update(mfa_code: mfa_code, mfa_sent_at: Time.current)

        # Send MFA mail (mailer must be configured with SMTP env vars)
        if Rails.env.development?
          Rails.logger.info("[DEV MFA] code for #{client.email.value}: #{mfa_code}")
        else
          MfaMailer.send_mfa_code(client.email.value, mfa_code).deliver_later
        end

        render json: { success: true, mfa_required: true, message: 'MFA code sent to your email' }
      rescue => e
        render json: { success: false, error: e.message }, status: :unauthorized
      end

      # Step 2: verify MFA code and return JWT
      def verify_mfa
        load_dependencies
        email = params[:email].to_s.strip.downcase
        code = params[:code].to_s.strip

        record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(email: email)
        return render(json: { success: false, error: 'Invalid email or code' }, status: :unauthorized) unless record

        # check code and expiry (10 minutes)
        if record.mfa_code == code && record.mfa_sent_at && record.mfa_sent_at > 10.minutes.ago
          # clear MFA fields
          record.update(mfa_code: nil, mfa_sent_at: nil)

          # generate token
          token = Application::UseCases::AuthenticateUserUseCase.new(client_repository).send(:generate_jwt_token, record.id)

          render json: { success: true, token: token }
        else
          render json: { success: false, error: 'Invalid or expired MFA code' }, status: :unauthorized
        end
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      private

      def load_dependencies
        require_domain_files
        require_application_files
        require_infrastructure_files
      end

      def client_repository
        Infrastructure::Persistence::Repositories::ActiveRecordClientRepository.new
      end

      def require_domain_files
        load 'app/domain/shared/value_object.rb'
        load 'app/domain/shared/entity.rb'
        load 'app/domain/shared/repository.rb'
        load 'app/domain/clients/value_objects/email.rb'
        load 'app/domain/clients/value_objects/money.rb'
        load 'app/domain/clients/entities/client.rb'
        load 'app/domain/clients/entities/portfolio.rb'
        load 'app/domain/clients/repositories/client_repository.rb'
        load 'app/domain/clients/repositories/portfolio_repository.rb'
      end

      def require_application_files
        load 'app/application/use_cases/authenticate_user_use_case.rb'
      end

      def require_infrastructure_files
        load 'app/models/client_record.rb'
        load 'app/infrastructure/persistence/repositories/active_record_client_repository.rb'
      end
    end
  end
end
