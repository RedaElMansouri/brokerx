Rails.application.routes.draw do
  # Metrics endpoint (Prometheus exposition format)
  get '/metrics', to: 'metrics#index'
  # Chemin racine — page statique
  root 'static#index'

  # Point de santé (utilisé par les probes/healthchecks)
  get '/health', to: proc { [200, {}, [{ status: 'ok', timestamp: Time.now.iso8601 }.to_json]] }

  # Routes API
  namespace :api do
    namespace :v1 do
      post 'clients/register', to: 'clients#create'
      get 'clients/verify', to: 'clients#verify'
      post 'auth/login', to: 'authentication#login'
      post 'auth/verify_mfa', to: 'authentication#verify_mfa'
      post 'deposits', to: 'deposits#create'
      get  'deposits', to: 'deposits#index'
      get 'portfolio', to: 'portfolios#show'
      post 'orders', to: 'orders#create'
      get  'orders/:id', to: 'orders#show'
      delete 'orders/:id', to: 'orders#destroy'
      post 'orders/:id/replace', to: 'orders#replace'
      post 'orders/:id/cancel', to: 'orders#cancel'
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
