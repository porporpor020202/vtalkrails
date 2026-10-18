class LanguageHelpsController < ApplicationController
  rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, with: -> { render_help_error("잠시 쉬었다가 다시 시도해주세요.", :too_many_requests) }

  def create
    if %w[question example].include?(params[:mode])
      question = DailyQuestion.find_signed(params[:question_token], purpose: :daily_question)
      unless question && question.asked_on == Date.current
        render_help_error("오늘의 질문을 새로 열어주세요.", :unprocessable_entity)
        return
      end
      if params[:mode] == "example"
        example = Rails.cache.fetch([ "question-example", question.id, question.updated_at.to_i ], expires_in: 7.days) do
          GeminiTranslation.new.call(text: question.question, mode: "example").fetch("korean")
        end
        render json: { example: example }
        return
      end
      @translation = Rails.cache.fetch([ "question-korean", question.id, question.updated_at.to_i ], expires_in: 7.days) do
        GeminiTranslation.new.call(text: question.question, mode: "question").fetch("korean")
      end
      render partial: "language_helps/question"
    else
      @input = params[:input_text].to_s.strip
      if @input.blank? || @input.length > 300
        render_help_error("한국어로 1~300자 이내로 적어주세요.", :unprocessable_entity)
        return
      end
      @result = GeminiTranslation.new.call(text: @input, mode: "answer")
      render partial: "language_helps/answer"
    end
  rescue GeminiText::Unavailable => error
    Rails.logger.warn("Translation unavailable: #{error.message}")
    render_help_error("지금은 표현을 가져오지 못했어요. 잠시 후 다시 시도해주세요.", :service_unavailable)
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
