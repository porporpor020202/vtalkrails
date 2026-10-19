class MarketingEventsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  rate_limit to: 90, within: 1.minute

  def create
    name = params[:name].to_s
    return head :unprocessable_entity unless MarketingEvent::CLIENT_NAMES.include?(name)
    return head :no_content if current_user&.admin?

    context = "daily"
    unless name == "app_open"
      question = DailyQuestion.find_signed(params[:question_token], purpose: :daily_question)
      unless question
        question = BonusPractice.find_signed(params[:question_token], purpose: :bonus_practice)
        context = "bonus"
        return head :unprocessable_entity unless current_user && question&.user_id == current_user.id && !question.completed?
      end
      return head :unprocessable_entity unless question&.asked_on == Date.current
    end
    track_marketing(name, context: context)
    head :no_content
  end
end
