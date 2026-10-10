class TextToSpeechesController < ApplicationController
  rate_limit to: 10, within: 1.minute, by: -> { current_user.id }, with: -> {
    render json: { error: "Please wait a minute before trying again." }, status: :too_many_requests
  }

  def create
    # Only synthesize a translation issued for this user, not arbitrary posted text.
    translation = Rails.application.message_verifier(:voice_helper_speech).verified(params[:speech_token].to_s, purpose: "read-aloud")
    unless translation && translation["user_id"] == current_user.id && translation["english"].is_a?(String) && translation["english"].length.between?(1, 1000)
      return render json: { error: "Please translate your recording again before listening." }, status: :unprocessable_entity
    end
    response.headers["Cache-Control"] = "private, no-store"
    speech = TextToSpeech.new
    audio = speech.call(translation["english"])
    send_data audio, type: speech.content_type, disposition: "inline"
  rescue TextToSpeech::Unavailable => error
    render json: { error: error.message }, status: :service_unavailable
  end
end
