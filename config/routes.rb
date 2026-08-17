Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "test" => "test#index"
  resource :modal, only: [ :new ]


  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker


  # Defines the root path route ("/")
  root to: redirect("/rooms")

  resources :configurations, only: [] do
    get :ios_v1, on: :collection
    get :android_v1, on: :collection
  end

  resources :rooms

  resource :settings, only: [ :show ], controller: "settings"

  resource :mypage, only: [ :show ], controller: "mypage"
  resource :map, only: [ :show ]

  resources :hikes, only: [] do
    get :map, on: :member
  end

  resources :demos, only: [ :index ] do
    collection do
      get :cors_allowed
      get :cors_blocked
    end
  end

  resource :apple_oauth_sessions, only: %i[ new create ] do
    collection do
      get :authenticate_by_token
      post :callback
      post :native_authenticate
    end
  end

  resource :google_oauth_sessions, only: %i[ new create ] do
    collection do
      get :authenticate_by_token
      get :callback
    end
  end

  resource :session
  resources :passwords, param: :token

  resources :notification_tokens, only: :create do
    post :test_push, on: :collection
  end

  resources :numbers, only: %i[index show]
end
