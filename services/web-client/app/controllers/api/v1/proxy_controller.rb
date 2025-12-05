# frozen_string_literal: true

module Api
  module V1
    class ProxyController < ApplicationController
      before_action :setup_client

      # Auth
      def auth_login
        proxy_post('/api/v1/auth/login')
      end

      def auth_verify_mfa
        proxy_post('/api/v1/auth/verify_mfa')
      end

      def auth_logout
        proxy_post('/api/v1/auth/logout')
      end

      # Clients - RESTful routes matching microservices
      def clients_create
        proxy_post('/api/v1/clients')
      end

      def clients_show
        proxy_get("/api/v1/clients/#{params[:id]}")
      end

      def clients_verify_email
        proxy_post("/api/v1/clients/#{params[:id]}/verify_email")
      end

      def clients_resend_verification
        proxy_post("/api/v1/clients/#{params[:id]}/resend_verification")
      end

      # Me (current user)
      def me
        proxy_get('/api/v1/me')
      end

      # Portfolio
      def portfolio_show
        proxy_get('/api/v1/portfolio')
      end

      def portfolio_show_by_id
        proxy_get("/api/v1/portfolios/#{params[:id]}")
      end

      def deposits_create
        proxy_post('/api/v1/deposits')
      end

      def deposits_index
        proxy_get('/api/v1/deposits')
      end

      # Orders
      def orders_index
        proxy_get('/api/v1/orders')
      end

      def orders_create
        proxy_post('/api/v1/orders')
      end

      def orders_show
        proxy_get("/api/v1/orders/#{params[:id]}")
      end

      def orders_replace
        proxy_post("/api/v1/orders/#{params[:id]}/replace")
      end

      def orders_cancel
        proxy_post("/api/v1/orders/#{params[:id]}/cancel")
      end

      def orders_destroy
        proxy_delete("/api/v1/orders/#{params[:id]}")
      end

      private

      def setup_client
        @client = Faraday.new(url: kong_gateway_url) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end
      end

      def kong_gateway_url
        ENV.fetch('KONG_GATEWAY_URL', 'http://localhost:8080')
      end

      def proxy_headers
        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }

        # Forward authorization header if present
        if request.headers['Authorization'].present?
          headers['Authorization'] = request.headers['Authorization']
        end

        # Forward apikey header if present (for Kong key-auth)
        if request.headers['apikey'].present?
          headers['apikey'] = request.headers['apikey']
        end

        # Forward idempotency key if present
        if request.headers['Idempotency-Key'].present?
          headers['Idempotency-Key'] = request.headers['Idempotency-Key']
        end

        headers
      end

      def proxy_get(path)
        query_string = request.query_string.present? ? "?#{request.query_string}" : ''
        response = @client.get("#{path}#{query_string}") do |req|
          req.headers = proxy_headers
        end
        render json: response.body, status: response.status
      rescue Faraday::Error => e
        render json: { error: "Gateway error: #{e.message}" }, status: :bad_gateway
      end

      def proxy_post(path)
        response = @client.post(path) do |req|
          req.headers = proxy_headers
          req.body = request.raw_post
        end
        render json: response.body, status: response.status
      rescue Faraday::Error => e
        render json: { error: "Gateway error: #{e.message}" }, status: :bad_gateway
      end

      def proxy_delete(path)
        response = @client.delete(path) do |req|
          req.headers = proxy_headers
        end
        render json: response.body, status: response.status
      rescue Faraday::Error => e
        render json: { error: "Gateway error: #{e.message}" }, status: :bad_gateway
      end
    end
  end
end
