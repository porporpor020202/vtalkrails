class VoiceMessagesController < ApplicationController
  before_action :set_room

  def create
    attributes = voice_message_params

    ApplicationRecord.transaction do
      @room.lock!
      unless @room.can_reply?(current_user)
        raise ActiveRecord::RecordInvalid.new(@room.tap do |room|
          room.errors.add(:base, "Wait for your partner to reply before recording again")
        end)
      end

      message = @room.voice_messages.build(
        sender: current_user,
        duration_ms: attributes.fetch(:duration_ms)
      )
      message.audio.attach(attributes.fetch(:audio))
      message.save!
      @room.update!(last_sender: current_user, last_message_at: Time.current)
    end

    render json: { redirect_url: room_path(@room) }, status: :created
  rescue ActionController::ParameterMissing, KeyError
    render json: { error: "A recorded voice message is required" }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def set_room
    @room = Room.involving(current_user).find(params[:room_id])
  end

  def voice_message_params
    params.require(:voice_message).permit(:audio, :duration_ms)
  end
end
