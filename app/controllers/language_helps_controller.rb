class LanguageHelpsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  rate_limit to: 20, within: 1.minute, by: -> { current_user&.id || request.remote_ip }, with: -> { render_help_error(t("ui.wait"), :too_many_requests) }

  def create
    if %w[question example].include?(params[:mode])
      question = DailyQuestion.find_signed(params[:question_token], purpose: :daily_question)
      unless question && question.asked_on == Date.current
        render_help_error(t("ui.refresh_question"), :unprocessable_entity)
        return
      end
      if params[:mode] == "example"
        example = Rails.cache.fetch([ "question-example", I18n.locale, question.id, question.updated_at.to_i ], expires_in: 7.days) do
          GeminiTranslation.new.call(text: question.question, mode: "example").fetch("translation")
        end
        render json: { example: example }
        return
      end
      @translation = Rails.cache.fetch([ "question-translation", I18n.locale, question.id, question.updated_at.to_i ], expires_in: 7.days) do
        GeminiTranslation.new.call(text: question.question, mode: "question").fetch("translation")
      end
      render partial: "language_helps/question"
    else
      @input = params[:input_text].to_s.strip
      if @input.blank? || @input.length > 300
        render_help_error(t("ui.input_length"), :unprocessable_entity)
        return
      end
      @result = GeminiTranslation.new.call(text: @input, mode: "answer")
      render partial: "language_helps/answer"
    end
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
