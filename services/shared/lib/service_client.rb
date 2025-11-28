# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# HTTP client for inter-service communication with distributed tracing support
module ServiceClient
  class Base
    TRACE_HEADER = 'X-Trace-ID'
    SPAN_HEADER = 'X-Span-ID'
    PARENT_SPAN_HEADER = 'X-Parent-Span-ID'
    SERVICE_HEADER = 'X-Source-Service'

    class << self
      def get(url, headers: {}, timeout: 5)
        request(:get, url, headers: headers, timeout: timeout)
      end

      def post(url, body: nil, headers: {}, timeout: 10)
        request(:post, url, body: body, headers: headers, timeout: timeout)
      end

      def put(url, body: nil, headers: {}, timeout: 10)
        request(:put, url, body: body, headers: headers, timeout: timeout)
      end

      def delete(url, headers: {}, timeout: 5)
        request(:delete, url, headers: headers, timeout: timeout)
      end

      private

      def request(method, url, body: nil, headers: {}, timeout: 5)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.use_ssl = uri.scheme == 'https'

        request = build_request(method, uri, body, headers)
        add_tracing_headers(request)

        start_time = Time.current
        response = http.request(request)
        duration = ((Time.current - start_time) * 1000).round(2)

        log_call(method, url, response.code, duration)

        {
          status: response.code.to_i,
          body: parse_body(response.body),
          headers: response.to_hash,
          duration_ms: duration
        }
      rescue StandardError => e
        log_error(method, url, e)
        {
          status: 0,
          body: nil,
          error: e.message,
          headers: {}
        }
      end

      def build_request(method, uri, body, headers)
        request = case method
                  when :get
                    Net::HTTP::Get.new(uri.request_uri)
                  when :post
                    Net::HTTP::Post.new(uri.request_uri)
                  when :put
                    Net::HTTP::Put.new(uri.request_uri)
                  when :delete
                    Net::HTTP::Delete.new(uri.request_uri)
                  else
                    raise ArgumentError, "Unknown HTTP method: #{method}"
                  end

        headers.each { |key, value| request[key] = value }
        request['Content-Type'] = 'application/json' unless headers.key?('Content-Type')
        request['Accept'] = 'application/json' unless headers.key?('Accept')

        if body && %i[post put].include?(method)
          request.body = body.is_a?(String) ? body : body.to_json
        end

        request
      end

      def add_tracing_headers(request)
        # Propagate trace context from current thread
        trace_id = Thread.current[:trace_id]
        span_id = Thread.current[:span_id]
        service_name = Rails.application.class.module_parent_name.underscore rescue 'unknown'

        request[TRACE_HEADER] = trace_id if trace_id
        request[PARENT_SPAN_HEADER] = span_id if span_id
        request[SPAN_HEADER] = SecureRandom.hex(16) # New span for outgoing call
        request[SERVICE_HEADER] = service_name
      end

      def parse_body(body)
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      def log_call(method, url, status, duration)
        Rails.logger.info({
          event: 'service_call',
          trace_id: Thread.current[:trace_id],
          span_id: Thread.current[:span_id],
          method: method.to_s.upcase,
          url: url,
          status: status,
          duration_ms: duration,
          timestamp: Time.current.iso8601(3)
        }.to_json)
      end

      def log_error(method, url, error)
        Rails.logger.error({
          event: 'service_call_error',
          trace_id: Thread.current[:trace_id],
          span_id: Thread.current[:span_id],
          method: method.to_s.upcase,
          url: url,
          error: error.message,
          error_class: error.class.name,
          timestamp: Time.current.iso8601(3)
        }.to_json)
      end
    end
  end

  # Client for Clients Service
  class ClientsService < Base
    BASE_URL = ENV.fetch('CLIENTS_SERVICE_URL', 'http://localhost:3001')

    class << self
      def verify_token(token)
        get("#{BASE_URL}/api/v1/auth/verify", headers: { 'Authorization' => "Bearer #{token}" })
      end

      def get_client(client_id)
        get("#{BASE_URL}/api/v1/clients/#{client_id}")
      end
    end
  end

  # Client for Portfolios Service
  class PortfoliosService < Base
    BASE_URL = ENV.fetch('PORTFOLIOS_SERVICE_URL', 'http://localhost:3002')

    class << self
      def get_portfolio(client_id)
        get("#{BASE_URL}/api/v1/portfolios/#{client_id}")
      end

      def reserve_funds(client_id, amount, order_id)
        post("#{BASE_URL}/internal/reserve", body: {
          client_id: client_id,
          amount: amount,
          order_id: order_id
        })
      end

      def release_funds(client_id, amount, order_id)
        post("#{BASE_URL}/internal/release", body: {
          client_id: client_id,
          amount: amount,
          order_id: order_id
        })
      end
    end
  end

  # Client for Orders Service
  class OrdersService < Base
    BASE_URL = ENV.fetch('ORDERS_SERVICE_URL', 'http://localhost:3003')

    class << self
      def get_orders(client_id)
        get("#{BASE_URL}/api/v1/orders?client_id=#{client_id}")
      end

      def get_order(order_id)
        get("#{BASE_URL}/api/v1/orders/#{order_id}")
      end
    end
  end
end
