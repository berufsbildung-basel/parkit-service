Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  namespace :api, defaults: { format: :json } do
    # devise_for :users
    namespace :v1 do
      resources :users do
        put :enable
        put :disable
      end
      resources :parking_spots do
        put :set_unavailable
        put :set_available
      end
      resources :vehicles
      resources :reservations
    end
  end
end
