class OnboardingController < ApplicationController
  before_action :redirect_completed_user
  before_action :load_countries

  def show
    @user = current_user
  end

  def update
    @user = current_user
    @user.assign_attributes(onboarding_params)

    if @user.save(context: :onboarding)
      redirect_to after_authentication_url, status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def redirect_completed_user
    return unless current_user.onboarding_complete?

    redirect_to after_authentication_url, status: :see_other
  end

  def load_countries
    @countries = Country.order(:name)
  end

  def onboarding_params
    params.require(:user).permit(:display_name, :country_code)
  end
end
