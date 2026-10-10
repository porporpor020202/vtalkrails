class VoiceHelpersController < ApplicationController
  rate_limit to: 10, within: 1.minute, by: -> { current_user.id }, with: -> {
    render json: { error: "Please wait a minute before trying again." }, status: :too_many_requests
  }

  def create
    audio = params.require(:audio)
    duration_ms = Integer(params.require(:duration_ms))
    unless audio.is_a?(ActionDispatch::Http::UploadedFile) && audio.size.between?(1, 2.megabytes) && duration_ms.between?(1, 30_000)
      return render json: { error: "Record up to 30 seconds of audio and try again." }, status: :unprocessable_entity
    end

    english = VoiceHelper.new(current_user).call(audio: audio)
    speech_token = Rails.application.message_verifier(:voice_helper_speech).generate(
      { "user_id" => current_user.id, "english" => english }, purpose: "read-aloud", expires_in: 1.hour)
    render json: { english: english, speech_token: speech_token }
  rescue ActionController::ParameterMissing, ArgumentError, TypeError
    render json: { error: "A recording and its duration are required." }, status: :bad_request
  rescue VoiceHelper::UnclearSpeech => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue VoiceHelper::Unavailable => error
    render json: { error: error.message }, status: :service_unavailable
  end
end
