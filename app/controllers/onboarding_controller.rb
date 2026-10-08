class OnboardingController < ApplicationController
  skip_before_action :require_onboarding
  before_action :redirect_completed_user

  def show
    @user = current_user

    if @user.display_name.blank?
      @user.update!(display_name: UserDisplayNameGenerator.display_name)
    end
  end

  def update
    @user = current_user
    @user.assign_attributes(onboarding_params)

    if @user.valid?(:onboarding)
      @user.age_confirmed_at = Time.current
      @user.onboarding_completed_at = Time.current
      @user.save!
      redirect_to root_path, status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def redirect_completed_user
    return unless current_user.onboarding_complete?

    redirect_to after_authentication_url, status: :see_other
  end

  def onboarding_params
    params.require(:user).permit(:native_language_id, :learning_language_id, :date_of_birth, :microphone_confirmed)
  end
end
