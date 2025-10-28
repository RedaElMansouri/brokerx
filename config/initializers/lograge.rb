# Enable structured access logs via lograge
Rails.application.configure do
  # Only enable in production by default; can be toggled via ENV
  enable_lograge = ENV.fetch('LOGRAGE_ENABLED', Rails.env.production?.to_s) == 'true'
  if enable_lograge
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_options = lambda do |event|
      headers = event.payload[:headers]
      ua = nil
      begin
        ua = headers['HTTP_USER_AGENT'] if headers.respond_to?(:[])
      rescue StandardError
        ua = nil
      end
      {
        time: Time.now.utc.iso8601,
        request_id: event.payload[:request_id],
        user_agent: ua,
        ip: event.payload[:ip],
        params: event.payload[:params]&.except('controller', 'action', 'format', 'utf8', 'authenticity_token')
      }
    end
  end
end
