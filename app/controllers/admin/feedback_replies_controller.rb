class Admin::FeedbackRepliesController < Admin::BaseController
  def create
    @feedback = Feedback.find(params[:feedback_id])
    @reply = @feedback.feedback_replies.build(reply_params)
    @reply.user = current_user

    if @reply.save
      redirect_to admin_feedback_path(@feedback), status: :see_other
    else
      render "admin/feedbacks/show", status: :unprocessable_entity
    end
  end

  private

  def reply_params
    params.require(:feedback_reply).permit(:body)
  end
end
