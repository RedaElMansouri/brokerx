module Infrastructure
  module Web
    module Middleware
      class InstanceHeaderMiddleware
        def initialize(app)
          @app = app
        end

        def call(env)
          status, headers, response = @app.call(env)
          begin
            svc = ENV['SERVICE_NAME'] || 'web'
            headers['X-Instance'] = svc
          rescue StandardError
            # ignore
          end
          [status, headers, response]
        end
      end
    end
  end
end
