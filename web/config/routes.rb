Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "tracks#index"

  resources :tracks, only: [:index, :new, :create, :show, :destroy] do
    member do
      get :download_stem
    end
  end
end
