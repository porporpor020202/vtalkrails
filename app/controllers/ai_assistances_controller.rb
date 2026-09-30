class AiAssistancesController < ApplicationController
  before_action :set_room
  before_action :require_vip
  after_action { response.headers["Cache-Control"] = "no-store" }

  def create
    return render(json: { error: "AI help is not configured yet." }, status: :service_unavailable) unless Ai::Client.configured?
    kind = params[:kind].to_s
    return head :unprocessable_entity unless AiAssistance::KINDS.include?(kind)
    source = @room.voice_messages.find(params[:source_message_id])
    if kind == "interpretation"
      return head :forbidden if source.sender_id == current_user.id
    elsif !@room.can_reply?(current_user) || source.id != @room.voice_messages.order(:created_at, :id).last&.id
      return render json: { error: "The conversation has moved on. Please reopen it." }, status: :conflict
    end

    input = kind == "translation" ? params[:draft].to_s.strip : nil
    if kind == "pronunciation"
      parent = current_user.ai_assistances.where(room: @room, source_message: source, status: "completed")
        .find(params[:parent_id])
      input = case parent.kind
      when "translation" then parent.result["english"]
      when "suggestions"
        index = Integer(params[:reply_index], exception: false)
        parent.result.fetch("replies", [])[index]&.fetch("english") if index && index.between?(0, 2)
      end
    end
    if %w[translation pronunciation].include?(kind) && (input.blank? || input.length > 1000)
      return render json: { error: "Enter a message of 1–1,000 characters." }, status: :unprocessable_entity
    end

    language = current_user.native_language.name
    key = Digest::SHA256.hexdigest(JSON.generate([ 1, current_user.id, @room.id, source.id, kind, language, input ]))
    assistance = AiAssistance.create_or_find_by!(request_key: key) do |record|
      record.assign_attributes(user: current_user, room: @room, source_message: source,
        kind: kind, native_language: language, input_text: input)
    end
    assistance.with_lock do
      # Permit recovery from a crashed worker without replaying completed requests.
      if assistance.status == "failed" || (%w[pending processing].include?(assistance.status) && assistance.updated_at < 15.minutes.ago)
        assistance.update!(status: "pending")
      end
      AiAssistanceJob.perform_later(assistance.id) if assistance.status == "pending"
    end
    render json: payload(assistance), status: :accepted
  end

  def show
    assistance = current_user.ai_assistances.where(room: @room).find(params[:id])
    return head :conflict unless assistance.current_turn?
    if params[:audio] == "1"
      return head :not_found unless assistance.status == "completed" && assistance.audio.attached?
      send_data assistance.audio.download, type: "audio/mpeg", disposition: "inline"
    else
      render json: payload(assistance)
    end
  end

  private

  def require_vip
    return if current_user.vip?
    render json: { error: "VIP includes AI help. Voice conversations are always free.", vip_url: vip_path }, status: :payment_required
  end

  def set_room
    @room = Room.involving(current_user).where.not(status: :deleted).find(params[:room_id])
  end

  def payload(assistance)
    {
      id: assistance.id, status: assistance.status,
      url: room_ai_assistance_path(@room, assistance),
      result: assistance.status == "completed" ? assistance.result : {},
      audio_url: assistance.status == "completed" && assistance.audio.attached? ?
        room_ai_assistance_path(@room, assistance, audio: 1) : nil
    }
  end
end
