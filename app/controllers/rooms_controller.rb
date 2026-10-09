class RoomsController < ApplicationController
  def index
    @rooms = Room.visible_to(current_user)
      .includes(:host, :opponent, :last_voice_message)
      .order(created_at: :desc, id: :desc)
    @voice_message_counts = VoiceMessage.where(room_id: @rooms.map(&:id)).group(:room_id).count
  end

  def show
    @room = Room.involving(current_user)
      .includes(:host, :opponent, :last_voice_message)
      .find(params[:id])

    @opponent = @room.opponent_for(current_user)
    @messages = @room.unavailable?(current_user) ? VoiceMessage.none : @room.voice_messages.with_attached_audio.order(:created_at, :id)
  end

  def destroy
    @room = Room.involving(current_user).find(params[:id])

    ApplicationRecord.transaction do
      @room.lock!
      if @room.deleted?
        @room.update!(dismissed_by_id: current_user.id) unless @room.deleted_by?(current_user)
      else
        @room.voice_messages.find_each do |message|
          message.destroy!
        end

        @room.update!(
          status: :deleted,
          deleted_by_id: current_user.id,
        )
      end
    end

    redirect_to rooms_path, status: :see_other
  end

end
