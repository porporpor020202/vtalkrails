class PagesController < ApplicationController
  allow_unauthenticated_access

  def privacy; end
  def support; end
  def delete_account; end
end
