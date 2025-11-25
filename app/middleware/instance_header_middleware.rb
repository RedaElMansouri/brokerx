class InstanceHeaderMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    begin
      # Support both SERVICE_NAME (gateway) and INSTANCE_ID (lb)
      instance = ENV['INSTANCE_ID'] || ENV['SERVICE_NAME'] || 'web'
      headers['X-Instance'] = instance
    rescue StandardError
      # ignore
    end
    [status, headers, response]
  end
end
