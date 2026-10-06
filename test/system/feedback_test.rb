require "application_system_test_case"

class FeedbackTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    @other = users(:korean_native)
    @admin = users(:japanese_native)

    @admin.update!(admin: true)
    sign_in(user: @user)
  end

  test "r_설정에서 피드백 게시판으로 이동해 글을 작성할 수 있다" do
    visit settings_path
    click_link "Send feedback"

    assert_current_path feedbacks_path
    click_link "New feedback"

    fill_in "Title", with: "녹음이 중간에 끊겨요"
    fill_in "Message", with: "갤럭시에서 녹음하다가 중간에 멈췄어요."

    assert_difference "Feedback.count", 1 do
      click_button "Send feedback"
      assert_selector "h1", text: "녹음이 중간에 끊겨요"
    end

    feedback = @user.feedbacks.sole
    assert_current_path feedback_path(feedback)
    assert_equal "갤럭시에서 녹음하다가 중간에 멈췄어요.", feedback.body
  end

  test "r_작성한 피드백을 목록에서 다시 열어 읽을 수 있다" do
    feedback = Feedback.create!(
      user: @user,
      title: "녹음 관련 문의",
      body: "녹음 시간이 궁금해요."
    )

    visit feedbacks_path
    click_link feedback.title

    assert_current_path feedback_path(feedback)
    assert_selector "h1", text: feedback.title
    assert_text feedback.body

    page.refresh
    assert_text feedback.body
  end

  test "r_작성자는 자기 피드백의 제목과 내용을 수정할 수 있다" do
    feedback = Feedback.create!(
      user: @user,
      title: "수정 전 제목",
      body: "수정 전 내용"
    )

    visit feedback_path(feedback)
    click_link "Edit feedback"

    fill_in "Title", with: "수정한 제목"
    fill_in "Message", with: "문제가 발생하는 조건을 추가했어요."
    click_button "Save changes"

    assert_current_path feedback_path(feedback)
    assert_selector "h1", text: "수정한 제목"
    assert_text "문제가 발생하는 조건을 추가했어요."

    feedback.reload
    assert_equal "수정한 제목", feedback.title
    assert_equal "문제가 발생하는 조건을 추가했어요.", feedback.body
  end

  test "r_사용자의 피드백 목록에는 자기 글만 표시된다" do
    own_feedback = Feedback.create!(
      user: @user, title: "내 문의", body: "내 문의 내용"
    )
    other_feedback = Feedback.create!(
      user: @other, title: "다른 사용자 문의", body: "다른 문의 내용"
    )

    visit feedbacks_path

    assert_link own_feedback.title, href: feedback_path(own_feedback)
    assert_no_link other_feedback.title
    assert_no_text other_feedback.body
  end

  test "r_운영자는 관리자 피드백 목록에서 여러 사용자의 문의를 확인할 수 있다" do
    first = Feedback.create!(
      user: @user, title: "녹음 문의", body: "녹음 관련 내용"
    )
    second = Feedback.create!(
      user: @other, title: "언어 문의", body: "언어 관련 내용"
    )

    sign_in(user: @admin)
    visit admin_feedbacks_path

    assert_current_path admin_feedbacks_path

    assert_link first.title, href: admin_feedback_path(first)
    assert_link second.title, href: admin_feedback_path(second)
  end

  test "r_운영자의 답글을 작성자가 읽고 같은 글에서 다시 답글을 보낼 수 있다" do
    feedback = Feedback.create!(
      user: @user,
      title: "녹음 문제",
      body: "녹음이 중간에 끊겨요."
    )

    sign_in(user: @admin)
    visit admin_feedback_path(feedback)
    assert_current_path admin_feedback_path(feedback)
    fill_in "Reply", with: "사용 중인 휴대폰 모델을 알려주세요."

    assert_difference -> { feedback.feedback_replies.count }, 1 do
      click_button "Send reply"
      assert_text "사용 중인 휴대폰 모델을 알려주세요."
    end

    assert_current_path admin_feedback_path(feedback)
    assert_equal @admin, feedback.feedback_replies.sole.user

    sign_in(user: @user)
    visit feedback_path(feedback)
    assert_text "사용 중인 휴대폰 모델을 알려주세요."
    fill_in "Reply", with: "갤럭시 S24를 사용하고 있어요."

    assert_difference -> { feedback.feedback_replies.count }, 1 do
      click_button "Send reply"
      assert_text "갤럭시 S24를 사용하고 있어요."
    end

    sign_in(user: @admin)
    visit admin_feedback_path(feedback)
    assert_current_path admin_feedback_path(feedback)

    assert_text feedback.body
    assert_text "사용 중인 휴대폰 모델을 알려주세요."
    assert_text "갤럭시 S24를 사용하고 있어요."

    # 두 답글이 같은 글에 저장됐고, 작성자도 운영자 → 사용자 순서로 기록됐는지 확인한다.
    assert_equal [ @admin.id, @user.id ],
      feedback.feedback_replies.order(:created_at, :id).pluck(:user_id)
  end
end
