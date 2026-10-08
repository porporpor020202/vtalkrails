require "application_system_test_case"

class FeedbackTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    @other = users(:korean_native)
    @admin = users(:japanese_native)

    @admin.update!(admin: true)
    sign_in(user: @user)
  end

  test "설정에서 피드백 게시판으로 이동해 글을 작성할 수 있다" do
    visit settings_path
    click_link "Send feedback"

    assert_current_path feedbacks_path
    click_link "New feedback"

    fill_in "Title", with: "Recording stops midway"
    fill_in "Message", with: "Recording stopped midway on my Galaxy phone."

    assert_difference "Feedback.count", 1 do
      click_button "Send feedback"
      assert_selector "h1", text: "Recording stops midway"
    end

    feedback = @user.feedbacks.sole
    assert_current_path feedback_path(feedback)
    assert_equal "Recording stopped midway on my Galaxy phone.", feedback.body
  end

  test "작성한 피드백을 목록에서 다시 열어 읽을 수 있다" do
    feedback = Feedback.create!(
      user: @user,
      title: "Recording inquiry",
      body: "What is the recording time limit?"
    )

    visit feedbacks_path
    click_link feedback.title

    assert_current_path feedback_path(feedback)
    assert_selector "h1", text: feedback.title
    assert_text feedback.body

    page.refresh
    assert_text feedback.body
  end

  test "작성자는 자기 피드백의 제목과 내용을 수정할 수 있다" do
    feedback = Feedback.create!(
      user: @user,
      title: "Original title",
      body: "Original content"
    )

    visit feedback_path(feedback)
    click_link "Edit feedback"

    fill_in "Title", with: "Updated title"
    fill_in "Message", with: "Added the conditions that cause the issue."
    click_button "Save changes"

    assert_current_path feedback_path(feedback)
    assert_selector "h1", text: "Updated title"
    assert_text "Added the conditions that cause the issue."

    feedback.reload
    assert_equal "Updated title", feedback.title
    assert_equal "Added the conditions that cause the issue.", feedback.body
  end

  test "사용자의 피드백 목록에는 자기 글만 표시된다" do
    own_feedback = Feedback.create!(
      user: @user, title: "My inquiry", body: "My inquiry content"
    )
    other_feedback = Feedback.create!(
      user: @other, title: "Another user's inquiry", body: "Another inquiry's content"
    )

    visit feedbacks_path

    assert_link own_feedback.title, href: feedback_path(own_feedback)
    assert_no_link other_feedback.title
    assert_no_text other_feedback.body
  end

  test "운영자는 관리자 피드백 목록에서 여러 사용자의 문의를 확인할 수 있다" do
    first = Feedback.create!(
      user: @user, title: "Recording inquiry", body: "Recording details"
    )
    second = Feedback.create!(
      user: @other, title: "Language inquiry", body: "Language details"
    )

    sign_in(user: @admin)
    visit admin_feedbacks_path

    assert_current_path admin_feedbacks_path

    assert_link first.title, href: admin_feedback_path(first)
    assert_link second.title, href: admin_feedback_path(second)
  end

  test "운영자의 답글을 작성자가 읽고 같은 글에서 다시 답글을 보낼 수 있다" do
    feedback = Feedback.create!(
      user: @user,
      title: "Recording issue",
      body: "Recording stops midway."
    )

    sign_in(user: @admin)
    visit admin_feedback_path(feedback)
    assert_current_path admin_feedback_path(feedback)
    fill_in "Reply", with: "Please tell us your phone model."

    assert_difference -> { feedback.feedback_replies.count }, 1 do
      click_button "Send reply"
      assert_text "Please tell us your phone model."
    end

    assert_current_path admin_feedback_path(feedback)
    assert_equal @admin, feedback.feedback_replies.sole.user

    sign_in(user: @user)
    visit feedback_path(feedback)
    assert_text "Please tell us your phone model."
    fill_in "Reply", with: "I use a Galaxy S24."

    assert_difference -> { feedback.feedback_replies.count }, 1 do
      click_button "Send reply"
      assert_text "I use a Galaxy S24."
    end

    sign_in(user: @admin)
    visit admin_feedback_path(feedback)
    assert_current_path admin_feedback_path(feedback)

    assert_text feedback.body
    assert_text "Please tell us your phone model."
    assert_text "I use a Galaxy S24."

    # 두 답글이 같은 글에 저장됐고, 작성자도 운영자 → 사용자 순서로 기록됐는지 확인한다.
    assert_equal [ @admin.id, @user.id ],
      feedback.feedback_replies.order(:created_at, :id).pluck(:user_id)
  end
end
