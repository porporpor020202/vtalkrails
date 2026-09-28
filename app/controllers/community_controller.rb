class CommunityController < ApplicationController
  before_action :set_community_language

  private

  def set_community_language
    @language = Language.where(id: [current_user.mother_language_id, current_user.learning_language_id])
      .find(params[:language_id])
    @community_tab = @language.id == current_user.mother_language_id ? "mother" : "learning"
    session[:language_tab] = @community_tab
    session[:conversation_mode] = "community"
  end

  def load_comments
    comments = @post.comments.includes(:user).order(:created_at, :id)
    if params[:after].present?
      cursor = @post.comments.find(params[:after])
      comments = comments.where("(created_at, id) > (?, ?)", cursor.created_at, cursor.id)
    end
    @comments = comments.limit(51).to_a
    @more_comments = @comments.size > 50
    @comments = @comments.first(50)
  end
end
