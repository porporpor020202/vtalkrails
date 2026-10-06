class Admin::FeedbacksController < Admin::BaseController
  def index
    @feedbacks = Feedback.includes(:user).order(created_at: :desc, id: :desc)
  end

  def show
    @feedback = Feedback.includes(:user).find(params[:id])
    @reply = @feedback.feedback_replies.build
  end
end
