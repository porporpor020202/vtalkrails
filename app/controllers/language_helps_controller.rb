class LanguageHelpsController < ApplicationController
  include AiAllowance
  allow_unauthenticated_access
  before_action :resume_session

  rate_limit to: 20, within: 1.minute, by: -> { current_user&.id || request.remote_ip }, with: -> { render_help_error(t("ui.wait"), :too_many_requests) }

  def create
    @question = DailyQuestion.find_signed(params[:question_token], purpose: :daily_question)
    unless @question && @question.asked_on == Date.current
      render_help_error(t("ui.refresh_question"), :unprocessable_entity)
      return
    end
    training_usage
    if %w[question example].include?(params[:mode])
      mode = params[:mode]
      cache_name = mode == "question" ? "question-translation" : "question-example"
      translation = Rails.cache.fetch([ cache_name, I18n.locale, @question.id, @question.updated_at.to_i ], expires_in: 7.days) do
        fetch_daily_ai!(mode: mode, text: @question.question) do
          GeminiTranslation.new.call(text: @question.question, mode: mode)
        end.fetch("translation")
      end
      if mode == "example"
        render json: { example: translation }
      else
        @translation = translation
        render partial: "language_helps/question"
      end
    else
      @input = params[:input_text].to_s.strip
      if @input.blank? || @input.length > 300
        render_help_error(t("ui.input_length"), :unprocessable_entity)
        return
      end
      @result = fetch_daily_ai!(mode: "answer", text: @input) do
        GeminiTranslation.new.call(text: @input, mode: "answer")
      end
      render partial: "language_helps/answer"
    end
  rescue AiUsage::DailyLimitExceeded => error
    @result = error.response if params[:mode] == "answer"
    render_help_error(t("ui.ai_daily_limit"), :too_many_requests)
  rescue AiUsage::TrialExpired
    render_help_error(t("ui.trial_ended_title"), :payment_required)
  rescue AiUsage::LoginRequired
    render_help_error(t("ui.trial_sign_in"), :unauthorized)
  rescue GeminiText::Unavailable => error
    Rails.logger.warn("Translation unavailable: #{error.message}")
    render_help_error(t("ui.help_error"), :service_unavailable)
  end

  private

  def render_help_error(message, status)
    if params[:mode] == "example"
      render json: { error: message }, status: status
      return
    end
    @input ||= params[:input_text].to_s.strip
    @error = message
    render partial: params[:mode] == "question" ? "language_helps/question" : "language_helps/answer", status: status
  end
end
