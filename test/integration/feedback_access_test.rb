require "test_helper"

class FeedbackAccessTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:english_native)
    @other = users(:korean_native)
    @feedback = Feedback.create!(
      user: @user,
      title: "비공개 문의",
      body: "작성자와 운영자만 볼 수 있는 내용"
    )
  end

  test "r_일반 사용자는 관리자 피드백 목록에 직접 접근할 수 없다" do
    sign_in_as(@user)
    get admin_feedbacks_path

    assert_response :forbidden
    assert_not_includes response.body, @feedback.body
  end

  test "r_일반 사용자는 자기 글이라도 관리자 피드백 상세 화면에 접근할 수 없다" do
    sign_in_as(@user)
    get admin_feedback_path(@feedback)

    assert_response :forbidden
    assert_not_includes response.body, @feedback.body
  end

  test "r_다른 사용자는 주소를 직접 입력해도 피드백을 읽을 수 없다" do
    sign_in_as(@other)
    get feedback_path(@feedback)

    assert_response :not_found
    assert_not_includes response.body, @feedback.body
  end

  test "r_다른 사용자는 직접 요청해도 피드백을 수정할 수 없다" do
    sign_in_as(@other)
    patch feedback_path(@feedback), params: {
      feedback: { title: "변조한 제목", body: "변조한 내용" }
    }

    assert_response :not_found
    @feedback.reload
    assert_equal "비공개 문의", @feedback.title
    assert_equal "작성자와 운영자만 볼 수 있는 내용", @feedback.body
  end

  test "r_다른 사용자는 직접 요청해도 피드백에 답글을 남길 수 없다" do
    sign_in_as(@other)

    assert_no_difference "FeedbackReply.count" do
      post feedback_feedback_replies_path(@feedback), params: {
        feedback_reply: { body: "관계없는 사용자의 답글" }
      }

      assert_response :not_found
    end
  end

  test "r_제목이나 내용이 비어 있으면 피드백을 저장하지 않는다" do
    sign_in_as(@user)

    [
      { title: "", body: "문의 내용" },
      { title: "문의 제목", body: "   " }
    ].each do |attributes|
      assert_no_difference "Feedback.count" do
        post feedbacks_path, params: { feedback: attributes }

        assert_response :unprocessable_entity
      end
    end
  end

  test "r_내용이 비어 있으면 답글을 저장하지 않는다" do
    sign_in_as(@user)

    assert_no_difference "FeedbackReply.count" do
      post feedback_feedback_replies_path(@feedback), params: {
        feedback_reply: { body: "   " }
      }

      assert_response :unprocessable_entity
    end
  end
end
