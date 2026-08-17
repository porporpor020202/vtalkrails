class NumbersController < ApplicationController
  allow_unauthenticated_access

  def index
  end

  def show
    @number = params[:id]
  end
end
