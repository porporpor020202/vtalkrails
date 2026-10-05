class RoomsController < ApplicationController
  def index
    @languages = [current_user.learning_language, current_user.native_language]
    @language = @languages.find { |language| language.id.to_s == params[:room_language_id] } ||
      current_user.learning_language
    @rooms = Room.visible_to(current_user)
      .where(language: @language)
      .includes(:host, :opponent)
      .order(created_at: :desc, id: :desc)
  end

  def show
    @room = Room.involving(current_user)
      .includes(:host, :opponent)
      .find(params[:id])

    @opponent = @room.opponent_for(current_user)
    @messages = @room.voice_messages.with_attached_audio.order(:created_at, :id)
  end

  def destroy
    @room = Room.involving(current_user).find(params[:id])

    ApplicationRecord.transaction do
      @room.lock!
      if @room.deleted?
        @room.update!(dismissed_by: current_user) unless @room.deleted_by?(current_user)
      else
        @room.voice_messages.find_each do |message|
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
