class LikesController < ApplicationController
  def create
    hike = Hike.find(params[:hike_id])
    hike.likes.find_or_create_by!(user: current_user)
    NewLikeNotifier.with(hike: hike).deliver(hike.user)
    redirect_to hike
  end

  def destroy
    hike = Hike.find(params[:hike_id])
    hike.likes.find_by(user: current_user)&.destroy!
    redirect_to hike
  end
end
