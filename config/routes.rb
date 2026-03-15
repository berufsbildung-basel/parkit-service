# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  devise_for :users,
             controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  root to: redirect(path: '/dashboard', status: 302)

  resource :profile, only: [:show, :edit, :update], controller: 'profile'

  get '/dashboard', controller: 'dashboard', action: 'welcome'
  get '/billing', controller: 'billing', action: 'index'

  resources :users do
    resources :reservations do
      put 'cancel', action: 'cancel'
    end
    resources :vehicles, controller: 'user_vehicles' do
      resources :reservations
    end
    get 'billing', controller: 'user_billing', action: 'index'
    resources :invoice_downloads, only: [:show], controller: 'user_invoice_downloads'
  end

  resources :parking_spots do
    member do
      patch :archive
      patch :unarchive
    end
  end

  resources :reservations
  resources :vehicles

  # Admin routes for billing management
  namespace :admin do
    resource :billing, only: [:show], controller: 'billing' do
      get :run
      get :preview
      post :execute
    end

    resources :invoices, only: %i[index show] do
      collection do
        post :refresh_all
      end
      member do
        post :send_email
        get :download_pdf
        post :refresh_status
        post :reset
      end
    end

    resources :billing_periods, only: [:show] do
      member do
        post :reset
      end
    end
  end

  namespace :api, defaults: { format: :json } do
    # devise_for :users
    namespace :v1 do
      # Returns available parking spots for a given date, user and vehicle
      get 'parking_spots/availability', action: :check_availability, controller: 'parking_spots'

      # List parking spots and any reservations + vehicles on today's date
      get 'parking_spots/today', action: :today, controller: 'parking_spots'

      resources :parking_spots do
        put :set_unavailable
        put :set_available
      end

      resources :reservations do
        put :cancel
      end

      resources :users do
        put :change_role
        put :disable
        put :enable
      end

      resources :vehicles
    end
  end
end
