Rails.application.routes.draw do
  resource :session
  get  "up"          => "rails/health#show",        as: :rails_health_check
  get  "legal"       => "pages#legal"
  get  "sitemap.xml" => "pages#sitemap", as: :sitemap, defaults: { format: :xml }

  root "pages#home"

  resources :tracks, only: [:index, :new, :create, :show, :destroy] do
    member do
      get :download_stem
    end
  end

  match "*path", to: "honeypot#trap", via: :all
end
