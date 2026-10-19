class BonusPracticesController < ApplicationController
  include AiAllowance
  rescue_from AiUsage::TrialExpired, with: :trial_expired
  rescue_from AiAllowance::TranslationRequired do
    render json: { error: t("ui.translate_before_recording") }, status: :unprocessable_entity
  end
  rate_limit to: 10, within: 1.minute, only: :create

  def create
    practice = DailyPractice.find_signed(params[:practice_token], purpose: :share_bonus)
    unless practice && practice.user_id == current_user.id && practice.practiced_on == Date.current
      render json: { error: t("ui.new_day"), redirect_url: root_path }, status: :conflict
      return
    end
    training_usage
    bonus = BonusPractice.unlock_for!(practice)
    render json: { redirect_url: bonus.completed? ? root_path : bonus_practice_path }, status: :created
  end

  def show
    @today = Date.current
    @bonus = current_user.bonus_practices.joins(:daily_practice).find_by(daily_practices: { practiced_on: @today })
    unless @bonus && !@bonus.completed?
      redirect_to root_path
      return
    end
    @trial_used = training_usage.training_dates.size
    @question = @bonus
    @question_token = @bonus.signed_id(purpose: :bonus_practice)
    @recording_endpoint = recording_bonus_practice_path
    @bonus_mode = true
    @guest = false
    @streak = current_user.streak
    @result = training_usage.help_data.dig("bonus_answer", "response")
    track_marketing("question_viewed", context: "bonus")
    render "daily_practices/show"
  end

  def recording
    bonus = BonusPractice.find_signed(params[:question_token], purpose: :bonus_practice)
    unless bonus && bonus.user_id == current_user.id && bonus.practiced_on == Date.current
      render json: { error: t("ui.new_day"), redirect_url: root_path }, status: :conflict
      return
    end
    training_usage
    bonus.with_lock do
      unless bonus.completed?
        bonus.assign_attributes(duration_ms: recording_params[:duration_ms], completed_at: Time.current, english_sentence: recording_english_sentence!(bonus: true))
        bonus.audio.attach(recording_params[:audio])
        bonus.save!
      end
    end
    track_marketing("practice_completed", context: "bonus", key: "bonus:#{bonus.id}", at: bonus.completed_at)
    render json: { redirect_url: root_path }, status: :created
  rescue ActiveRecord::RecordInvalid
    render json: { error: t("ui.invalid_recording") }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    render json: { error: t("ui.send_audio") }, status: :unprocessable_entity
  end

  private

  def trial_expired
    if request.format.json?
      render json: { error: t("ui.trial_ended_title"), redirect_url: root_path }, status: :payment_required
    else
      redirect_to root_path
    end
  end

  def recording_params
    params.require(:daily_practice).permit(:audio, :duration_ms)
  end
end
