class DailyPracticesController < ApplicationController
  def show
    @today = Date.current
    @question = DailyQuestion.for_date(@today)
    @practice = current_user.daily_practices.find_by(practiced_on: @today)
    @streak = current_user.streak(today: @today)
    if @practice
      @resets_at = @today.next_day.in_time_zone
      @week = (@today.beginning_of_week..@today.end_of_week).to_a
      @completed_dates = current_user.daily_practices.where(practiced_on: @week).pluck(:practiced_on)
    end
  end

  def create
    date = Date.current
    question = DailyQuestion.find_signed(params[:question_token], purpose: :daily_question)
    unless question&.asked_on == date
      render json: { error: "새로운 하루가 시작됐어요. 오늘의 질문을 다시 열어주세요.", redirect_url: root_path }, status: :conflict
      return
    end

    current_user.with_lock do
      unless current_user.daily_practices.exists?(practiced_on: date)
        practice = current_user.daily_practices.build(daily_question: question, practiced_on: date, completed_at: Time.current, duration_ms: recording_params[:duration_ms])
        practice.audio.attach(recording_params[:audio])
        practice.save!
      end
    end
    render json: { redirect_url: root_path }, status: :created
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    render json: { error: "녹음한 음성을 보내주세요." }, status: :unprocessable_entity
  end

  def audio
    practice = current_user.daily_practices.find_by!(practiced_on: Date.current)
    response.headers["Cache-Control"] = "private, no-store"
    send_data practice.audio.download, type: practice.audio.content_type, disposition: :inline
  end

  private

  def recording_params
    params.require(:daily_practice).permit(:audio, :duration_ms)
  end
end
