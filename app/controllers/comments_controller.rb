class CommentsController < CommunityController
  before_action :set_post

  def create
    @comment = @post.comments.build(params.require(:comment).permit(:body))
    @comment.user = current_user
    if @comment.save
      # Open the page containing the new comment, including when the thread has >50 replies.
      previous = @post.comments.where("(created_at, id) < (?, ?)", @comment.created_at, @comment.id)
        .order(created_at: :desc, id: :desc).offset(49).first
      redirect_to language_post_path(@language, @post, tab: selected_language_tab,
        after: previous&.id, anchor: "comment_#{@comment.id}"), status: :see_other
    else
      load_comments
      render "posts/show", status: :unprocessable_entity
    end
  end

  def destroy
    @post.comments.where(user: current_user).find(params[:id]).destroy!
    redirect_to language_post_path(@language, @post, tab: selected_language_tab), notice: "Comment deleted.", status: :see_other
  end

  private

  def set_post
    @post = @language.posts.includes(:user).find(params[:post_id])
  end
end
