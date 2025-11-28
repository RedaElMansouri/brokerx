# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#show'
  get '/ready', to: 'health#ready'

  # Metrics endpoint for Prometheus
  get '/metrics', to: 'metrics#show'

  # ActionCable WebSocket
  mount ActionCable.server => '/cable'

  namespace :api do
    namespace :v1 do
      # UC-04: Market Data (REST fallback)
      resources :market_data, only: [:index, :show], param: :symbol

      # UC-05: Place Order
      # UC-06: Modify/Cancel Order
      resources :orders, only: [:index, :show, :create] do
        member do
          post :replace    # Modify order
          post :cancel     # Cancel order
        end
      end

      # UC-08: Execution Reports
      resources :executions, only: [:index, :show]

      # Trades history
      resources :trades, only: [:index, :show]
    end
  end
end
