Rails.application.routes.draw do
  # Metrics endpoint (Prometheus exposition format)
  get '/metrics', to: 'metrics#index'
  # Chemin racine — page statique
  root 'static#index'

  # Point de santé (utilisé par les probes/healthchecks)
  get '/health', to: proc { [200, {}, [{ status: 'ok', timestamp: Time.now.iso8601 }.to_json]] }

  # Routes API (Monolith fallback - Kong Gateway routes to microservices)
  namespace :api do
    namespace :v1 do
      # Clients (UC-01)
      resources :clients, only: [:create] do
        member do
          get :verify
        end
      end
      
      # Authentication (UC-02)
      post 'auth/login', to: 'authentication#login'
      post 'auth/verify_mfa', to: 'authentication#verify_mfa'
      
      # Deposits (UC-03)
      resources :deposits, only: [:create, :index]
      get 'portfolio', to: 'portfolios#show'
      
      # Orders (UC-04 to UC-08)
      resources :orders, only: [:create, :show, :destroy] do
        member do
          post :replace
          post :cancel
        end
      end
    end
  end

  # Pages UI
  get '/orders', to: 'orders#index'
  get '/portfolio', to: 'portfolios#show'

  # ActionCable WebSocket endpoint
  mount ActionCable.server => '/cable'

  # Catch-all 404
  match '*path', to: 'application#route_not_found', via: :all
end
