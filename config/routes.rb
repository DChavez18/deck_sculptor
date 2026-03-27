Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "decks#index"

  resources :decks do
    resources :deck_cards, only: [ :create, :update, :destroy ]
    member do
      get  :suggestions
      get  :analysis
      get  :intent
      post :save_intent
    end
  end

  resources :commanders, only: [ :index, :show ] do
    collection do
      get :search
    end
  end

  resources :cards, only: [] do
    collection do
      get :search
    end
  end
end
