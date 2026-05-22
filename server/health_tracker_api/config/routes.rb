Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/register",    to: "auth#register"
      post "auth/login",       to: "auth#login"
      post "auth/totp_setup",  to: "auth#totp_setup"
      post "auth/totp_verify", to: "auth#totp_verify"

      resources :devices, only: [ :create, :update ]

      resources :health_events, only: [ :index, :show, :create ] do
        member do
          post :amend
        end
      end

      resources :medications, only: [ :index, :create, :update ] do
        member do
          post :merge
        end
      end
      resources :reports, only: [ :index, :show ], param: :id
      resources :summaries, only: [ :index ]
      resource  :sync,      only: [ :create ]
    end
  end
end
