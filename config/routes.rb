Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "support" => "pages#support", as: :support
  get "about" => "pages#about", as: :about
  get "privacy" => "pages#privacy", as: :privacy
  get "child_safety" => "pages#child_safety", as: :child_safety
  get "delete_account" => "pages#delete_account", as: :delete_account
  get "delete_account/confirm" => "account_deletions#show", as: :confirm_account_deletion

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker


  root "rooms#index"
  get "vip/terms", to: "vips#terms"
  resource :vip, only: :show do
    post :checkout
    post :verify
    post :manage
    get :status
  end

  resources :rooms, only: %i[index show destroy] do
    resources :voice_messages, only: :create do
      get :audio, on: :member
    end
    resource :safety, only: :show, controller: "room_safeties"
    resource :report, only: :create, controller: "content_reports"
    resource :block, only: :create, controller: "user_blocks"
  end
  resource :voice_drop, only: :create

  resource :language_setup, only: %i[show update]
  resource :onboarding, only: %i[show update], controller: "onboarding"

  resource :room_reception, only: :update

  resource :settings, only: %i[show update], controller: "settings"

  resources :feedbacks, only: %i[index new create show edit update] do
    resources :feedback_replies, only: :create
  end

  namespace :admin do
    resources :content_reports, only: %i[index show update]
    resources :voice_messages, only: [] do
      get :audio, on: :member
    end
    resources :users, only: [] do
      resource :suspension, only: :create, controller: "suspensions"
    end
    resources :feedbacks, only: %i[index show] do
      resources :feedback_replies, only: :create
    end
  end

  resource :profile, only: [ :show ], controller: "profile"
  resource :account, only: [ :destroy ]

  resource :apple_oauth_sessions, only: %i[ new create ] do
    collection do
      get :authenticate_by_token
      post :callback
      post :native_authenticate
    end
  end

  resource :google_oauth_sessions, only: %i[ new create ] do
    collection do
      get :callback
      get :authenticate_by_token
      post :native_authenticate
    end
  end

  resource :session, only: %i[new destroy]

  resources :notification_tokens, only: :create do
    post :test_push, on: :collection
  end
end
