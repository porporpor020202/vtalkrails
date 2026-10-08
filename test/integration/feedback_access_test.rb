require "test_helper"

class FeedbackAccessTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:english_native)
    @other = users(:korean_native)
    @feedback = Feedback.create!(
      user: @user,
      title: "Private inquiry",
      body: "Content visible only to the author and administrators"
    )
  end

  test "일반 사용자는 관리자 피드백 목록에 직접 접근할 수 없다" do
    sign_in_as(@user)
    get admin_feedbacks_path

    assert_response :forbidden
    assert_not_includes response.body, @feedback.body
  end

  test "일반 사용자는 자기 글이라도 관리자 피드백 상세 화면에 접근할 수 없다" do
    sign_in_as(@user)
    get admin_feedback_path(@feedback)

    assert_response :forbidden
    assert_not_includes response.body, @feedback.body
  end

  test "다른 사용자는 주소를 직접 입력해도 피드백을 읽을 수 없다" do
    sign_in_as(@other)
    get feedback_path(@feedback)

    assert_response :not_found
    assert_not_includes response.body, @feedback.body
  end

  test "다른 사용자는 직접 요청해도 피드백을 수정할 수 없다" do
    sign_in_as(@other)
    patch feedback_path(@feedback), params: {
      feedback: { title: "Tampered title", body: "Tampered content" }
    }

    assert_response :not_found
    @feedback.reload
    assert_equal "Private inquiry", @feedback.title
    assert_equal "Content visible only to the author and administrators", @feedback.body
  end

  test "다른 사용자는 직접 요청해도 피드백에 답글을 남길 수 없다" do
    sign_in_as(@other)

    assert_no_difference "FeedbackReply.count" do
      post feedback_feedback_replies_path(@feedback), params: {
        feedback_reply: { body: "Reply from an unrelated user" }
      }

      assert_response :not_found
    end
  end

  test "제목이나 내용이 비어 있으면 피드백을 저장하지 않는다" do
    sign_in_as(@user)

    [
      { title: "", body: "Inquiry content" },
      { title: "Inquiry title", body: "   " }
    ].each do |attributes|
      assert_no_difference "Feedback.count" do
        post feedbacks_path, params: { feedback: attributes }

        assert_response :unprocessable_entity
      end
    end
  end

  test "내용이 비어 있으면 답글을 저장하지 않는다" do
    sign_in_as(@user)

    assert_no_difference "FeedbackReply.count" do
      post feedback_feedback_replies_path(@feedback), params: {
        feedback_reply: { body: "   " }
      }

      assert_response :unprocessable_entity
    end
  end
end
