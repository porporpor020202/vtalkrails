class ContentReportsController < ApplicationController
  def create
    room = Room.involving(current_user).find(params[:room_id])
    report = room.content_reports.build(
      content_report_params.merge(
        reporter: current_user,
        reported_user: room.opponent_for(current_user)
      )
    )

    saved = ApplicationRecord.transaction do
      User.where(id: [current_user.id, report.reported_user_id]).order(:id).lock.load
      if report.save
        UserBlock.find_or_create_by!(blocker: current_user, blocked: report.reported_user)
        true
      else
        false
      end
    end

    if saved
      redirect_to room_path(room), notice: "Report submitted. Our safety team will review it."
    else
      @room = room
      @opponent = room.opponent_for(current_user)
      @content_report = report
      @blocked = UserBlock.exists_between?(current_user, @opponent)
      render "room_safeties/show", status: :unprocessable_entity
    end
  end

  private

  def content_report_params
    params.require(:content_report).permit(:reason, :details)
  end
end
