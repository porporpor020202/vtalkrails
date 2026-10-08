class VoiceMessagesController < ApplicationController
  before_action :set_room

  def create
    attributes = voice_message_params

    ApplicationRecord.transaction do
      @room.lock!
      unless !@room.unavailable?(current_user) && @room.can_reply?(current_user)
        @room.errors.add(:base, "You can reply after your partner responds.")
        raise ActiveRecord::RecordInvalid.new(@room)
      end

      message = @room.voice_messages.build(
        sender: current_user,
        duration_ms: attributes.fetch(:duration_ms)
      )
      message.audio.attach(attributes.fetch(:audio))
      message.save!
    end

    render json: { redirect_url: room_path(@room) }, status: :created
  rescue ActionController::ParameterMissing, KeyError
    render json: { error: "A recorded voice message is required" }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def audio
    raise ActiveRecord::RecordNotFound if @room.unavailable?(current_user)
    message = @room.voice_messages.find(params[:id])
    raise ActiveRecord::RecordNotFound unless message.audio.attached?

    response.headers["Cache-Control"] = "private, no-store"
    send_data message.audio.download,
      filename: message.audio.filename.to_s,
      type: message.audio.content_type,
      disposition: "inline"
  end

  private

  def set_room
    @room = Room.involving(current_user).find(params[:room_id])
  end

  def voice_message_params
    params.require(:voice_message).permit(:audio, :duration_ms)
  end
end
