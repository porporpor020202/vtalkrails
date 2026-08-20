class SettingsController < ApplicationController
  def show
    @child_safety_contact_email = ENV.fetch("PRIVACY_CONTACT_EMAIL", "privacy@vtalks.net")
  end
end
