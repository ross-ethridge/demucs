Rails.application.routes.draw do
  resource :session
resource :account, only: %i[show destroy]
  get  "up"          => "rails/health#show",        as: :rails_health_check
  get  "legal"       => "pages#legal"
  get  "sitemap.xml" => "pages#sitemap", as: :sitemap, defaults: { format: :xml }
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

  match "*path", to: "honeypot#trap", via: :all
end
