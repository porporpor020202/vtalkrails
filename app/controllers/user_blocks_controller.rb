class UserBlocksController < ApplicationController
  def create
    room = Room.involving(current_user).find(params[:room_id])
    blocked_user = room.opponent_for(current_user)

    ApplicationRecord.transaction do
      UserBlock.find_or_create_by!(blocker: current_user, blocked: blocked_user)

      Room.between(current_user, blocked_user).where.not(status: :deleted).find_each do |active_room|
        active_room.update!(
          status: :deleted,
          deleted_by: current_user,
          last_sender: nil,
          last_message_at: Time.current
        )
      end
    end

    redirect_to rooms_path, notice: "User blocked. You will not be matched with this person again."
  end
end
