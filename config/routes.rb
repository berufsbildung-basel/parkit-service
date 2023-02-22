Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  resources :users

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
