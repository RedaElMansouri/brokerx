# frozen_string_literal: true

# Facade for Clients Service (UC-01, UC-02)
# Strangler Fig Pattern - delegates to clients-service microservice
class ClientsFacade < BaseFacade
  # UC-01: Register a new client
  def register(email:, password:, name:)
    make_request(:post, '/api/v1/clients/register', {
      email: email,
      password: password,
      name: name
    })
  end

  # UC-01: Verify email
  def verify_email(token:)
    make_request(:get, '/api/v1/clients/verify_email', { token: token })
  end

  # UC-02: Login (step 1 - sends MFA code)
  def login(email:, password:)
    make_request(:post, '/api/v1/auth/login', {
      email: email,
      password: password
    })
  end

  # UC-02: Verify MFA (step 2 - returns JWT)
  def verify_mfa(session_token:, mfa_code:)
    make_request(:post, '/api/v1/auth/verify_mfa', {
      session_token: session_token,
      mfa_code: mfa_code
    })
  end

  # Get client profile
  def get_profile(jwt_token:)
    make_request(:get, '/api/v1/clients/profile', {}, {
      'Authorization' => "Bearer #{jwt_token}"
    })
  end

  # Health check
  def health
    make_request(:get, '/health')
  end

  protected

  def service_url
    ENV.fetch('CLIENTS_SERVICE_URL', 'http://localhost:3001')
  end
end
