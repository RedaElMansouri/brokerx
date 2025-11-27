# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check endpoint
  get '/health', to: 'health#show'
  
  # Metrics endpoint for Prometheus
  get '/metrics', to: 'metrics#show'

  # API v1 namespace
  namespace :api do
    namespace :v1 do
      # UC-01: Inscription et Vérification du Client
      resources :clients, only: [:create, :show] do
        member do
          get :verify_email
          post :verify_email
          post :resend_verification
        end
      end

      # UC-02: Authentification Multi-Facteurs (MFA)
      namespace :auth do
        post :login
        post :verify_mfa
        post :logout
        post :refresh_token
      end

      # Session management
      get :me, to: 'sessions#show'
    end
  end
end
