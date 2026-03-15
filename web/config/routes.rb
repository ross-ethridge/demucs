Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  get "up"    => "rails/health#show", as: :rails_health_check
  get "legal" => "pages#legal"

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
