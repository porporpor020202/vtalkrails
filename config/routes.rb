Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "daily_practices#show"
  resource :daily_practice, only: [:show, :create] do
    get :audio
  end
  resource :language_help, only: :create
  resource :settings, only: :show
  resource :account, only: :destroy
  get "delete_account/confirm" => "account_deletions#show", as: :confirm_account_deletion
  get "privacy" => "pages#privacy"
  get "support" => "pages#support"
  get "delete_account" => "pages#delete_account"

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

end
