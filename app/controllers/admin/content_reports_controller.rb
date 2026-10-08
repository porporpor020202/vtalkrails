class Admin::ContentReportsController < Admin::BaseController
  def index
    @reports = ContentReport.includes(:reporter, :reported_user)
      .order(Arel.sql("CASE WHEN reason = 'child_exploitation' THEN 0 ELSE 1 END"), created_at: :asc, id: :asc)
  end

  def show
    @report = ContentReport.find(params[:id])
  end

  def update
    @report = ContentReport.find(params[:id])
    @report.assign_attributes(params.require(:content_report).permit(:status, :resolution))
    @report.reviewed_by = current_user
    @report.reviewed_at = Time.current

    if @report.save
      redirect_to admin_content_report_path(@report), notice: "Report reviewed."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
