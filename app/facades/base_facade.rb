# frozen_string_literal: true

# Base class for all service facades
# Part of Strangler Fig pattern - allows monolith to delegate to microservices
class BaseFacade
  class ServiceUnavailableError < StandardError; end
  class ServiceError < StandardError; end

  def initialize(options = {})
    @timeout = options[:timeout] || 5
    @open_timeout = options[:open_timeout] || 2
    @use_fallback = options.fetch(:use_fallback, true)
  end

  protected

  def service_url
    raise NotImplementedError, "Subclasses must implement #service_url"
  end

  def http_client
    @http_client ||= build_http_client
  end

  def build_http_client
    Faraday.new(url: service_url) do |faraday|
      faraday.request :json
      faraday.response :json, parser_options: { symbolize_names: true }
      faraday.options.timeout = @timeout
      faraday.options.open_timeout = @open_timeout
      faraday.adapter Faraday.default_adapter
    end
  end

  def make_request(method, path, params = {}, headers = {})
    response = case method
               when :get
                 http_client.get(path, params, headers)
               when :post
                 http_client.post(path, params, headers)
               when :put
                 http_client.put(path, params, headers)
               when :patch
                 http_client.patch(path, params, headers)
               when :delete
                 http_client.delete(path, params, headers)
               end

    handle_response(response)
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    Rails.logger.error("[#{self.class.name}] Connection failed: #{e.message}")
    raise ServiceUnavailableError, "Service unavailable: #{e.message}"
  end

  def handle_response(response)
    case response.status
    when 200..299
      { success: true, data: response.body, status: response.status }
    when 400..499
      { success: false, error: response.body, status: response.status }
    when 500..599
      raise ServiceError, "Service error: #{response.status}"
    else
      { success: false, error: "Unknown response: #{response.status}", status: response.status }
    end
  end

  def with_fallback
    yield
  rescue ServiceUnavailableError, ServiceError => e
    if @use_fallback
      Rails.logger.warn("[#{self.class.name}] Using fallback due to: #{e.message}")
      yield_fallback
    else
      raise
    end
  end

  def yield_fallback
    raise NotImplementedError, "Subclasses must implement #yield_fallback for fallback mode"
  end
end
