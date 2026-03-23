Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"

      resources :devices, only: [ :create, :update ]

      resources :health_events, only: [ :index, :show, :create ] do
        member do
          post :amend
        end
      end

      resources :medications, only: [ :index, :create ]
      resources :summaries, only: [ :index ]
      resource  :sync,      only: [ :create ]
    end
  end
end
