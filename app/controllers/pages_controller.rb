class PagesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_privacy_contact, only: %i[privacy delete_account]

  def privacy; end

  def delete_account; end

  private

  def set_privacy_contact
    @privacy_operator_name = ENV.fetch("PRIVACY_OPERATOR_NAME", "say one thing 운영팀")
    @privacy_contact_email = ENV.fetch("PRIVACY_CONTACT_EMAIL", "privacy@vtalks.net")
  end
end
