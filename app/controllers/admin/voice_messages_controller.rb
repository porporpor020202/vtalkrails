class Admin::VoiceMessagesController < Admin::BaseController
  def audio
    message = VoiceMessage.find(params[:id])
    raise ActiveRecord::RecordNotFound unless message.audio.attached?
    response.headers["Cache-Control"] = "private, no-store"
    send_data message.audio.download, type: message.audio.content_type, disposition: "inline"
  end
end
