Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "daily_practices#show"
  resource :native_language, only: %i[show update]
  get "admin" => "admin/users#index", as: :admin
  get "admin/users/:id" => "admin/users#show", as: :admin_user
  get "admin/users/:id/recordings/:practice_id" => "admin/users#audio", as: :audio_admin_user
  resource :daily_practice, only: [:show, :create] do
    get :audio
  end
  resource :language_help, only: :create
  resource :bonus_practice, only: %i[show create] do
    post :recording
  end
  get "admin/users/:id/bonus_recordings/:practice_id" => "admin/users#bonus_audio", as: :bonus_audio_admin_user
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
