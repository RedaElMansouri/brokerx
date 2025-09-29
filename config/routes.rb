Rails.application.routes.draw do
  # Root path - Page d'accueil statique
  root 'static#index'

  # Health check
  get '/health', to: proc { [200, {}, [{ status: 'ok', timestamp: Time.now.iso8601 }.to_json]] }

  # API routes
  namespace :api do
    namespace :v1 do
      post 'clients/register', to: 'clients#create'
      get 'clients/verify', to: 'clients#verify'
      post 'auth/login', to: 'authentication#login'
  post 'auth/verify_mfa', to: 'authentication#verify_mfa'
      post 'orders', to: 'orders#create'
    end
  end

  # Orders UI page
  get '/orders', to: 'orders#index'

  match '*path', to: 'application#route_not_found', via: :all
end
