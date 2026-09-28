class VoiceDropsController < ApplicationController
  def create
    drop = VoiceDropDispatcher.new(current_user, language: selected_say_language).call(
      audio: voice_message_params.fetch(:audio),
      duration_ms: voice_message_params.fetch(:duration_ms),
      request_key: params.require(:request_key)
    )

    flash[:notice] = "Sent to #{drop.recipient_count} #{'listener'.pluralize(drop.recipient_count)}."
    render json: { redirect_url: rooms_path(tab: selected_language_tab), recipient_count: drop.recipient_count, drop_id: drop.id }, status: :created
  rescue VoiceDropDispatcher::RequestConflict => e
    render json: { error: e.message }, status: :conflict
  rescue VoiceDropDispatcher::NoRecipientAvailable => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing, KeyError
    render json: { error: "A recorded voice message and request key are required" }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def voice_message_params
    params.require(:voice_message).permit(:audio, :duration_ms)
  end
end
