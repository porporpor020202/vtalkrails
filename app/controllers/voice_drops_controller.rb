class VoiceDropsController < ApplicationController
  def create
    room = VoiceDropDispatcher.new(current_user).call(
      audio: voice_message_params.fetch(:audio),
      duration_ms: voice_message_params.fetch(:duration_ms)
    )

    render json: { redirect_url: room_path(room) }, status: :created
  rescue VoiceDropDispatcher::NoRecipientAvailable => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing, KeyError
    render json: { error: "A recorded voice message is required" }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def voice_message_params
    params.require(:voice_message).permit(:audio, :duration_ms)
  end
end
