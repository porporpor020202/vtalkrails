class RoomsController < ApplicationController
  def index
    @rooms = current_user.rooms.order(updated_at: :desc)
  end

  def show
  end

  def new
  end
end
