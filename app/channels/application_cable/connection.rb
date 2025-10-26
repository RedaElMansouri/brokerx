module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_client_id

    def connect
      self.current_client_id = authenticate!
      reject_unauthorized_connection unless current_client_id
    end

    private

    def authenticate!
      token = extract_token
      return nil unless token

      begin
        payload, = JWT.decode(
          token,
          Rails.application.secret_key_base,
          true,
          {
            algorithm: 'HS256',
            iss: 'brokerx',
            verify_iss: true,
            aud: 'brokerx.web',
            verify_aud: true,
            verify_expiration: true
          }
        )
        payload['client_id']
      rescue JWT::DecodeError
        nil
      end
    end

    def extract_token
      # Support query param ?token=Bearer+... or raw token; also Authorization header
      raw = request.params['token']
      raw ||= request.headers['Authorization']
      return nil unless raw
      raw.to_s.gsub(/^Bearer\s+/i, '')
    end
  end
end
