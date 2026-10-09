class RoomReceptionsController < ApplicationController
  def update
    current_user.update!(receive_new_rooms: !current_user.receive_new_rooms?)
    message = current_user.receive_new_rooms? ? "New voices are allowed." :
      "New voices are paused. Messages in existing conversations are unaffected."
    redirect_to rooms_path,
      flash: { reception_notice: message }, status: :see_other
  end
end
