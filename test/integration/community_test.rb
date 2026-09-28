require "test_helper"

class CommunityTest < ActionDispatch::IntegrationTest
  setup do
    @english = languages(:english)
    @korean = languages(:korean)
    @author = users(:english_speaker)
    @reader = users(:korean_learner)
    @post = Post.create!(user: @author, language: @english, body: "English community post")
    sign_in_as @author
  end

  test "both language roles share a community and cross-language content is excluded" do
    korean_post = Post.create!(user: @reader, language: @korean, body: "Korean-only post")
    get language_posts_path(@english, tab: "learning")
    assert_response :success
    assert_select "#post_#{@post.id}"
    assert_select "#post_#{korean_post.id}", count: 0
    sign_out
    sign_in_as @reader
    get language_posts_path(@english, tab: "learning")
    assert_response :success
    assert_select "#post_#{@post.id}"
    assert_select "#bottom-tab-bar[data-bottom-nav-tab-value='mother']"
    assert_select "nav[aria-label='Conversation mode'] a[href='#{rooms_path(tab: 'mother')}']"
    assert_select "#bottom-tab-bar a[href='#{language_posts_path(@korean, tab: 'learning')}']"
  end

  test "post creation assigns the signed in author and route language and renders text safely" do
    assert_difference "Post.count", 1 do
      post language_posts_path(@english), params: { post: { body: '<script>alert("x")</script>', user_id: @reader.id, language_id: @korean.id } }
    end
    created = Post.order(:id).last
    assert_equal @author, created.user
    assert_equal @english, created.language
    follow_redirect!
    assert_response :success
    assert_select "#post_#{created.id} script", count: 0
    assert_includes response.body, "&lt;script&gt;"
    assert_select "form[action='#{language_post_comments_path(@english, created, tab: 'learning')}']"
  end

  test "blank and oversized posts and comments show validation messages" do
    ["   ", "a" * 2001].each do |body|
      assert_no_difference("Post.count") { post language_posts_path(@english), params: { post: { body: body } } }
      assert_response :unprocessable_entity
      assert_select "[role='alert']"
    end
    ["\n ", "b" * 501].each do |body|
      assert_no_difference("Comment.count") { post language_post_comments_path(@english, @post), params: { comment: { body: body } } }
      assert_response :unprocessable_entity
      assert_select "[role='alert']"
    end
  end

  test "comment authorship and deletion are scoped to the post and current user" do
    sign_out
    sign_in_as @reader
    post language_post_comments_path(@english, @post), params: { comment: { body: "A reply", user_id: @author.id } }
    assert_response :see_other
    comment = @post.comments.last
    assert_equal @reader, comment.user
    assert_equal 1, @post.reload.comments_count
    follow_redirect!
    assert_select "#comment_#{comment.id}", text: /A reply/
    assert_no_difference("Post.count") { delete language_post_path(@english, @post) }
    assert_response :not_found

    sign_out
    sign_in_as @author
    assert_no_difference("Comment.count") { delete language_post_comment_path(@english, @post, comment) }
    assert_response :not_found
    sign_out
    sign_in_as @reader
    delete language_post_comment_path(@english, @post, comment)
    assert_response :see_other
    assert_equal 0, @post.reload.comments_count
  end

  test "unauthorized language and mismatched nested ids cannot read or mutate records" do
    french = Language.create!(name: "French", code: "fr")
    get language_posts_path(french)
    assert_response :not_found
    assert_no_difference("Post.count") { post language_posts_path(french), params: { post: { body: "No" } } }
    assert_response :not_found
    get language_post_path(@korean, @post)
    assert_response :not_found
    assert_no_difference("Comment.count") { post language_post_comments_path(@korean, @post), params: { comment: { body: "No" } } }
    assert_response :not_found
    second = Post.create!(user: @author, language: @english, body: "Second")
    comment = second.comments.create!(user: @author, body: "Scoped")
    assert_no_difference("Comment.count") { delete language_post_comment_path(@english, @post, comment) }
    assert_response :not_found
  end

  test "deleting a post removes its comments and account deletion cleans authored content" do
    @post.comments.create!(user: @reader, body: "Reply")
    assert_difference("Comment.count", -1) do
      assert_difference("Post.count", -1) { delete language_post_path(@english, @post) }
    end
    assert_response :see_other
    post = Post.create!(user: @reader, language: @english, body: "Reader's post")
    post.comments.create!(user: @author, body: "Author reply")
    delete account_path
    assert_response :see_other
    assert_equal 0, post.reload.comments_count
  end

  test "community requires sign in and completed language setup" do
    sign_out
    get language_posts_path(@english)
    assert_redirected_to new_session_path
    @author.update!(mother_language: nil, learning_language: nil)
    sign_in_as @author
    get language_posts_path(@english)
    assert_redirected_to language_setup_path
  end

  test "posts and comments paginate without skipping tied timestamps" do
    now = Time.current.change(usec: 0)
    @post.update_columns(created_at: now - 1.minute)
    posts = 22.times.map { |i| Post.create!(user: @author, language: @english, body: "Post #{i}", created_at: now) }
    get language_posts_path(@english)
    assert_select "article[id^='post_']", count: 20
    cursor = posts.sort_by(&:id).reverse[19]
    get language_posts_path(@english, before: cursor.id)
    assert_select "article[id^='post_']", count: 3
    assert_select "#post_#{cursor.id}", count: 0
    comments = 52.times.map { |i| @post.comments.create!(user: @author, body: "Reply #{i}", created_at: now) }
    get language_post_path(@english, @post)
    assert_select "article[id^='comment_']", count: 50
    get language_post_path(@english, @post, after: comments[49].id)
    assert_select "article[id^='comment_']", count: 2
  end
end
