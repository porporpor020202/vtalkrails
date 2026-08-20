class PagesController < ApplicationController
  allow_unauthenticated_access

  def privacy
    @privacy_operator_name = ENV.fetch("PRIVACY_OPERATOR_NAME", "say one thing 운영팀")
    @privacy_contact_email = ENV.fetch("PRIVACY_CONTACT_EMAIL", "privacy@vtalks.net")
  end
end
