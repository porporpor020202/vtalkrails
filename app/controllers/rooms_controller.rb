class RoomsController < ApplicationController
  def index
    @rooms = Room.visible_to(current_user)
      .includes(:user, :opponent, :last_sender, voice_messages: { audio_attachment: :blob })
      .order(Arel.sql("COALESCE(last_message_at, rooms.updated_at) DESC"))
      .to_a
      .uniq { |room| room.opponent_for(current_user).id }
  end

  def show
    @room = Room.involving(current_user)
      .includes(:user, :opponent, voice_messages: { audio_attachment: :blob })
      .find(params[:id])

    if @room.hidden_for?(current_user)
      redirect_to rooms_path, status: :see_other
      return
    end

    @opponent = @room.opponent_for(current_user)
    @messages = @room.deleted? ? [] : @room.voice_messages.order(:created_at)
  end

  def destroy
    @room = Room.involving(current_user).find(params[:id])

    ApplicationRecord.transaction do
      @room.lock!
      if @room.deleted?
        @room.update!(dismissed_by: current_user) unless @room.deleted_by?(current_user)
      else
        @room.voice_messages.find_each do |message|
          message.audio.purge if message.audio.attached?
          message.destroy!
        end

        @room.update!(
          status: :deleted,
          deleted_by: current_user,
          last_sender: nil,
          last_message_at: Time.current
        )
      end
    end

    redirect_to rooms_path, status: :see_other
  end
end
