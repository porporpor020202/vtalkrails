class FeedbackRepliesController < ApplicationController
  def create
    @feedback = current_user.feedbacks.find(params[:feedback_id])
    @reply = @feedback.feedback_replies.build(reply_params)
    @reply.user = current_user

    if @reply.save
      redirect_to @feedback, status: :see_other
    else
      render "feedbacks/show", status: :unprocessable_entity
    end
  end

  private

  def reply_params
    params.require(:feedback_reply).permit(:body)
  end
end
