# frozen_string_literal: true

# Middleware for distributed tracing across microservices
# Propagates trace_id and span_id through HTTP headers
module Middleware
  class DistributedTracing
    TRACE_HEADER = 'X-Trace-ID'
    SPAN_HEADER = 'X-Span-ID'
    PARENT_SPAN_HEADER = 'X-Parent-Span-ID'
    SERVICE_HEADER = 'X-Source-Service'

    def initialize(app, service_name: 'unknown')
      @app = app
      @service_name = service_name
    end

    def call(env)
      # Extract or generate trace context
      trace_id = env["HTTP_#{TRACE_HEADER.upcase.tr('-', '_')}"] || generate_id
      parent_span_id = env["HTTP_#{SPAN_HEADER.upcase.tr('-', '_')}"]
      span_id = generate_id
      source_service = env["HTTP_#{SERVICE_HEADER.upcase.tr('-', '_')}"]

      # Store in thread-local for logging
      Thread.current[:trace_id] = trace_id
      Thread.current[:span_id] = span_id
      Thread.current[:parent_span_id] = parent_span_id
      Thread.current[:source_service] = source_service

      # Add to request for controllers
      env['distributed_tracing.trace_id'] = trace_id
      env['distributed_tracing.span_id'] = span_id
      env['distributed_tracing.parent_span_id'] = parent_span_id
      env['distributed_tracing.source_service'] = source_service

      # Log incoming request with trace context
      log_request(env, trace_id, span_id, parent_span_id, source_service)

      # Call the app
      status, headers, response = @app.call(env)

      # Add trace headers to response
      headers[TRACE_HEADER] = trace_id
      headers[SPAN_HEADER] = span_id
      headers[SERVICE_HEADER] = @service_name

      # Log response
      log_response(env, status, trace_id, span_id)

      [status, headers, response]
    ensure
      # Clean up thread-local
      Thread.current[:trace_id] = nil
      Thread.current[:span_id] = nil
      Thread.current[:parent_span_id] = nil
      Thread.current[:source_service] = nil
    end

    private

    def generate_id
      SecureRandom.hex(16)
    end

    def log_request(env, trace_id, span_id, parent_span_id, source_service)
      Rails.logger.info({
        event: 'request_started',
        service: @service_name,
        trace_id: trace_id,
        span_id: span_id,
        parent_span_id: parent_span_id,
        source_service: source_service,
        method: env['REQUEST_METHOD'],
        path: env['PATH_INFO'],
        timestamp: Time.current.iso8601(3)
      }.to_json)
    end

    def log_response(env, status, trace_id, span_id)
      Rails.logger.info({
        event: 'request_completed',
        service: @service_name,
        trace_id: trace_id,
        span_id: span_id,
        method: env['REQUEST_METHOD'],
        path: env['PATH_INFO'],
        status: status,
        timestamp: Time.current.iso8601(3)
      }.to_json)
    end
  end
end
