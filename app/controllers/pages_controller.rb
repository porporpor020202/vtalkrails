class PagesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_privacy_contact, only: %i[privacy child_safety delete_account]
  before_action :set_support_contact, only: :support

  def support; end

  def privacy; end

  def child_safety; end

  def delete_account; end

  private

  def set_privacy_contact
    @privacy_operator_name = ENV.fetch("PRIVACY_OPERATOR_NAME", "say one thing Team")
    @privacy_contact_email = ENV.fetch("PRIVACY_CONTACT_EMAIL", "privacy@vtalks.net")
  end

  def set_support_contact
    @support_contact_email = ENV.fetch("SUPPORT_CONTACT_EMAIL", "privacy@vtalks.net")
  end
end
