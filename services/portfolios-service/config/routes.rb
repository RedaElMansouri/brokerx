# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#show'
  get '/ready', to: 'health#ready'

  # Metrics endpoint for Prometheus
  get '/metrics', to: 'metrics#show'

  namespace :api do
    namespace :v1 do
      # Portfolios
      resources :portfolios, only: [:index, :show, :create] do
        member do
          get :balance
          get :transactions
        end
      end

      # Deposits (UC-03 - Dépôt de fonds idempotent)
      resources :deposits, only: [:index, :show, :create]

      # Withdrawals
      resources :withdrawals, only: [:index, :show, :create]
    end
  end

  # ============ INTERNAL APIs (for inter-service communication) ============
  # These endpoints are called by Orders Service for Saga pattern
  namespace :internal do
    # Reserve funds for an order
    post 'reserve', to: 'funds#reserve'
    # Release reserved funds (compensation)
    post 'release', to: 'funds#release'
    # Debit funds after execution
    post 'debit', to: 'funds#debit'
    # Check balance
    get 'balance/:client_id', to: 'funds#balance'
  end
end
