Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "decks#index"

  resources :decks do
    resources :deck_cards,          only: [ :create, :update, :destroy ]
    resources :suggestion_feedbacks, only: [ :create ]
    resources :deck_chats,           only: [ :create ]
    resources :deck_imports,         only: [ :create ]
    member do
      get  :suggestions
      get  :more_suggestions
      get  :analysis
      get  :intent
      post :save_intent
      get  :export
      get  "cards/:category", to: "decks#cards_by_category", as: :deck_cards_by_category
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

  get "/templates",           to: "templates#index", as: :templates
  get "/templates/:archetype", to: "templates#show",  as: :template
end
