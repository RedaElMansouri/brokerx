# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#show'

  # Static pages
  root 'static#index'

  # Auth pages
  get '/login', to: 'static#index'
  get '/register', to: 'static#index'

  # Protected pages (rendered client-side, auth checked via JS)
  get '/portfolio', to: 'portfolios#show'
  get '/orders', to: 'orders#index'

  # API proxy to Kong Gateway - match microservices routes exactly
  namespace :api do
    namespace :v1 do
      # Auth
      post 'auth/login', to: 'proxy#auth_login'
      post 'auth/verify_mfa', to: 'proxy#auth_verify_mfa'
      post 'auth/logout', to: 'proxy#auth_logout'

      # Clients - RESTful routes
      post 'clients', to: 'proxy#clients_create'
      get 'clients/:id', to: 'proxy#clients_show'
      post 'clients/:id/verify_email', to: 'proxy#clients_verify_email'
      post 'clients/:id/resend_verification', to: 'proxy#clients_resend_verification'

      # Me (current user)
      get 'me', to: 'proxy#me'

      # Portfolio
      get 'portfolio', to: 'proxy#portfolio_show'
      get 'portfolios/:id', to: 'proxy#portfolio_show_by_id'
      post 'deposits', to: 'proxy#deposits_create'
      get 'deposits', to: 'proxy#deposits_index'

      # Orders
      get 'orders', to: 'proxy#orders_index'
      post 'orders', to: 'proxy#orders_create'
      get 'orders/:id', to: 'proxy#orders_show'
      post 'orders/:id/replace', to: 'proxy#orders_replace'
      post 'orders/:id/cancel', to: 'proxy#orders_cancel'
      delete 'orders/:id', to: 'proxy#orders_destroy'
    end
  end
end
