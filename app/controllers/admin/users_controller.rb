class Admin::UsersController < ApplicationController
  before_action :require_admin

  def index
    response.headers["Cache-Control"] = "private, no-store"
    @query = params[:q].to_s.strip.first(200)
    @page = [ params[:page].to_i, 1 ].max
    scope = User.all
    scope = scope.where("email_address ILIKE ?", "%#{User.sanitize_sql_like(@query)}%") if @query.present?
    @total = scope.count
    @users = scope.order(created_at: :desc, id: :desc).offset((@page - 1) * 50).limit(50).to_a
    @dates = DailyPractice.where(user_id: @users.map(&:id)).order(practiced_on: :desc).pluck(:user_id, :practiced_on).group_by(&:first).transform_values { |rows| rows.map(&:last) }
    @last_practice = DailyPractice.where(user_id: @users.map(&:id)).group(:user_id).maximum(:completed_at)
    @last_login = Session.where(user_id: @users.map(&:id)).group(:user_id).maximum(:created_at)
    @total_users = User.count
    @today_users = User.where(created_at: Date.current.all_day).count
    @today_practices = DailyPractice.where(practiced_on: Date.current).where.not(user_id: nil).count
    @practiced_users = DailyPractice.where.not(user_id: nil).distinct.count(:user_id)
  end

  def show
    response.headers["Cache-Control"] = "private, no-store"
    @user = User.find(params[:id])
    @page = [ params[:page].to_i, 1 ].max
    @total = @user.daily_practices.count
    @practices = @user.daily_practices.includes(:daily_question, { bonus_practice: { audio_attachment: :blob } }, audio_attachment: :blob).order(practiced_on: :desc).offset((@page - 1) * 30).limit(30)
  end

  def audio
    practice = User.find(params[:id]).daily_practices.find(params[:practice_id])
    raise ActiveRecord::RecordNotFound unless practice.audio.attached?

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data practice.audio.download, type: practice.audio.content_type, disposition: :inline
  end

  def bonus_audio
    practice = User.find(params[:id]).bonus_practices.find(params[:practice_id])
    raise ActiveRecord::RecordNotFound unless practice.completed? && practice.audio.attached?

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data practice.audio.download, type: practice.audio.content_type, disposition: :inline
  end

  private

  def require_admin
    head :forbidden unless current_user.admin?
  end
end
