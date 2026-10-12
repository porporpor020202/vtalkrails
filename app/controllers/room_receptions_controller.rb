class RoomReceptionsController < ApplicationController
  def update
    current_user.update!(receive_new_rooms: !current_user.receive_new_rooms?)
    message = current_user.receive_new_rooms? ? "Receiving new voices is enabled." :
      "New voices will not be received.\nMessages in existing conversations are unaffected."
    redirect_to(params[:return_to] == "settings" ? settings_path : rooms_path,
      flash: { reception_notice: message }, status: :see_other)
  end
end
