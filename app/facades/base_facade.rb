# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

# Base class for all service facades
# Part of Strangler Fig pattern - allows monolith to delegate to microservices
# Uses Ruby's stdlib Net::HTTP to avoid native gem dependencies
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

  def make_request(method, path, params = {}, headers = {})
    uri = URI.join(service_url, path)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = @timeout
    http.open_timeout = @open_timeout
    http.use_ssl = uri.scheme == 'https'
    
    request = build_request(method, uri, params, headers)
    response = http.request(request)
    
    handle_response(response)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[#{self.class.name}] Connection failed: #{e.message}")
    raise ServiceUnavailableError, "Service unavailable: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("[#{self.class.name}] Request failed: #{e.message}")
    raise ServiceError, "Service error: #{e.message}"
  end

  def build_request(method, uri, params, headers)
    case method
    when :get
      uri.query = URI.encode_www_form(params) if params.any?
      request = Net::HTTP::Get.new(uri)
    when :post
      request = Net::HTTP::Post.new(uri)
      request.body = params.to_json
      request['Content-Type'] = 'application/json'
    when :put
      request = Net::HTTP::Put.new(uri)
      request.body = params.to_json
      request['Content-Type'] = 'application/json'
    when :patch
      request = Net::HTTP::Patch.new(uri)
      request.body = params.to_json
      request['Content-Type'] = 'application/json'
    when :delete
      request = Net::HTTP::Delete.new(uri)
    end
    
    headers.each { |key, value| request[key] = value }
    request
  end

  def handle_response(response)
    status = response.code.to_i
    body = begin
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError
      response.body
    end

    case status
    when 200..299
      { success: true, data: body, status: status }
    when 400..499
      { success: false, error: body, status: status }
    when 500..599
      raise ServiceError, "Service error: #{status}"
    else
      { success: false, error: "Unknown response: #{status}", status: status }
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
