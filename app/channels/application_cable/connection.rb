module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_client_id

    def connect
      self.current_client_id = authenticate!
      reject_unauthorized_connection unless current_client_id
      begin
        Infrastructure::Observability::Metrics.inc_counter('cable_connections_total', {})
        # naive gauge update based on thread count of streams is tricky; keep a monotonic counter + best-effort gauge
        Infrastructure::Observability::Metrics.set_gauge('cable_connections', (Infrastructure::Observability::Metrics.instance_variable_get(:@gauges)['cable_connections'].values.first || 0) + 1)
      rescue StandardError
      end
    end

    def disconnect
      begin
        current = Infrastructure::Observability::Metrics.instance_variable_get(:@gauges)['cable_connections'].values.first || 1
        Infrastructure::Observability::Metrics.set_gauge('cable_connections', [current - 1, 0].max)
      rescue StandardError
      end
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
