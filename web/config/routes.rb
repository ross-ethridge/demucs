Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  resource :account, only: %i[show destroy]
  get  "up"          => "rails/health#show",        as: :rails_health_check
  get  "legal"       => "pages#legal"
  get  "verify"      => "verifications#show",       as: :verify_email
  get  "unverified"  => "verifications#unverified", as: :unverified
  post "resend_verification" => "verifications#resend", as: :resend_verification

  namespace :payments do
    get  :success
    get  :cancel
    post :webhook
  end

  root "pages#home"

  resources :tracks, only: [:index, :new, :create, :show, :destroy] do
    member do
      get :download_stem
    end
  end
end
