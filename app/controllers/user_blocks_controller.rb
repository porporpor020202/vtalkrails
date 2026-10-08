class UserBlocksController < ApplicationController
  def create
    room = Room.involving(current_user).find(params[:room_id])
    blocked_user = room.opponent_for(current_user)

    ApplicationRecord.transaction do
      User.where(id: [current_user.id, blocked_user.id]).order(:id).lock.load
      UserBlock.find_or_create_by!(blocker: current_user, blocked: blocked_user)

    end

    redirect_to rooms_path, notice: "User blocked. You will not be matched with this person again."
  end
end
