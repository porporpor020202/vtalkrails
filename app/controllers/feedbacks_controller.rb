class FeedbacksController < ApplicationController
  before_action :set_feedback, only: %i[show edit update]

  def index
    @feedbacks = current_user.feedbacks.order(created_at: :desc, id: :desc)
  end

  def show
    @reply = @feedback.feedback_replies.build
  end

  def new
    @feedback = current_user.feedbacks.build
  end

  def create
    @feedback = current_user.feedbacks.build(feedback_params)
    if @feedback.save
      redirect_to @feedback, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @feedback.update(feedback_params)
      redirect_to @feedback, status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_feedback
    @feedback = current_user.feedbacks.find(params[:id])
  end

  def feedback_params
    params.require(:feedback).permit(:title, :body)
  end
end
