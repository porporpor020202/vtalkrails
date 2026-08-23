class ContentReportsController < ApplicationController
  def create
    room = Room.involving(current_user).find(params[:room_id])
    report = room.content_reports.build(
      content_report_params.merge(
        reporter: current_user,
        reported_user: room.opponent_for(current_user)
      )
    )

    if report.save
      redirect_to room_safety_path(room), notice: "Report submitted. Our safety team will review it."
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
