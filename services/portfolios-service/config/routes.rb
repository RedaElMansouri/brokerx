# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#show'
  get '/ready', to: 'health#ready'

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
end
