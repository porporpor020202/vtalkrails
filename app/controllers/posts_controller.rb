class PostsController < CommunityController
  def index
    @post = Post.new
    load_posts
  end

  def show
    @post = @language.posts.includes(:user).find(params[:id])
    @comment = Comment.new
    load_comments
  end

  def create
    @post = @language.posts.build(params.require(:post).permit(:body))
    @post.user = current_user
    if @post.save
      redirect_to language_post_path(@language, @post, tab: selected_language_tab), status: :see_other
    else
      load_posts
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @language.posts.where(user: current_user).find(params[:id]).destroy!
    redirect_to language_posts_path(@language, tab: selected_language_tab), notice: "Post deleted.", status: :see_other
  end

  private

  def load_posts
    posts = @language.posts.includes(:user).order(created_at: :desc, id: :desc)
    if params[:before].present?
      cursor = @language.posts.find(params[:before])
      posts = posts.where("(created_at, id) < (?, ?)", cursor.created_at, cursor.id)
    end
    @posts = posts.limit(21).to_a
    @more_posts = @posts.size > 20
    @posts = @posts.first(20)
  end
end
