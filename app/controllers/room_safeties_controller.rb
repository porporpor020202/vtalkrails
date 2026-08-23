class RoomSafetiesController < ApplicationController
  def show
    @room = Room.involving(current_user).find(params[:room_id])
    @opponent = @room.opponent_for(current_user)
    @content_report = ContentReport.new
    @blocked = UserBlock.exists_between?(current_user, @opponent)
  end
end
