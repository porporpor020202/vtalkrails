class DailyPracticesController < ApplicationController
  include AiAllowance
  allow_unauthenticated_access only: %i[show create]
  before_action :resume_session, only: %i[show create]
  rescue_from AiUsage::TrialExpired, with: :trial_expired
  rescue_from AiUsage::LoginRequired, with: :training_login_required
  rescue_from AiAllowance::TranslationRequired do
    render json: { error: t("ui.translate_before_recording") }, status: :unprocessable_entity
  end
  rate_limit to: 10, within: 1.minute, only: :create

  def show
    unless selected_native_language
      render "native_languages/show"
      return
    end
    @trial_used = training_usage.training_dates.size
    @today = Date.current
    @question = DailyQuestion.for_date(@today)
    @guest = current_user.nil?
    @practice = @guest ? DailyPractice.find_by(id: session[:guest_practice_id], user_id: nil, practiced_on: @today) : current_user.daily_practices.find_by(practiced_on: @today)
    @result = training_usage.help_data.dig("answer", "response")
    @saved = session.delete(:practice_saved)
    @streak = current_user&.streak(today: @today)
    if @practice
      @bonus = @practice.bonus_practice unless @guest
      @resets_at = @today.next_day.in_time_zone
      @week = (@today.beginning_of_week..@today.end_of_week).to_a
      @completed_dates = @guest ? [ @practice.practiced_on ] : current_user.daily_practices.where(practiced_on: @week).pluck(:practiced_on)
    else
      track_marketing("question_viewed")
    end
  end

  def create
    date = Date.current
    question = DailyQuestion.find_signed(params[:question_token], purpose: :daily_question)
    unless question&.asked_on == date
      render json: { error: t("ui.new_day"), redirect_url: root_path }, status: :conflict
      return
    end

    training_usage
    unless current_user
      practice = DailyPractice.find_by(id: session[:guest_practice_id], user_id: nil, practiced_on: date)
      unless practice
        practice = DailyPractice.new(daily_question: question, practiced_on: date, completed_at: Time.current, duration_ms: recording_params[:duration_ms], english_sentence: recording_english_sentence!)
        practice.audio.attach(recording_params[:audio])
        practice.save!
        session[:guest_practice_id] = practice.id
        ExpireGuestPracticeJob.set(wait: 24.hours).perform_later(practice.id)
      end
      track_marketing("practice_completed", key: "practice:#{practice.id}", at: practice.completed_at)
      render json: { redirect_url: root_path }, status: :created
      return
    end

    current_user.with_lock do
      practice = current_user.daily_practices.find_by(practiced_on: date)
      unless practice
        practice = current_user.daily_practices.build(daily_question: question, practiced_on: date, completed_at: Time.current, duration_ms: recording_params[:duration_ms], english_sentence: recording_english_sentence!)
        practice.audio.attach(recording_params[:audio])
        practice.save!
      end
      @completed_practice = practice
    end
    track_marketing("practice_completed", key: "practice:#{@completed_practice.id}", at: @completed_practice.completed_at)
    render json: { redirect_url: root_path }, status: :created
  rescue ActiveRecord::RecordInvalid
    render json: { error: t("ui.invalid_recording") }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    render json: { error: t("ui.send_audio") }, status: :unprocessable_entity
  end

  def audio
    practice = current_user.daily_practices.find_by!(practiced_on: Date.current)
    response.headers["Cache-Control"] = "private, no-store"
    send_data practice.audio.download, type: practice.audio.content_type, disposition: :inline
  end

  private

  def trial_expired
    if request.format.json?
      render json: { error: t("ui.trial_ended_title"), redirect_url: root_path }, status: :payment_required
    else
      render :trial_ended
    end
  end

  def training_login_required
    if request.format.json?
      render json: { error: t("ui.trial_sign_in"), redirect_url: new_session_path }, status: :unauthorized
    else
      redirect_to new_session_path, status: :see_other
    end
  end

  def recording_params
    params.require(:daily_practice).permit(:audio, :duration_ms)
  end
end
