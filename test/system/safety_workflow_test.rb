require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class SafetyWorkflowTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @sender = users(:english_native)
    @recipient = users(:korean_native)
    @admin = users(:japanese_native)
    @admin.update!(admin: true, native_language: languages(:korean), learning_language: languages(:english))

    complete_onboarding(@sender)
    complete_onboarding(@recipient)
    complete_onboarding(@admin)

    @room = Room.create!(host: @sender, opponent: @recipient, language: languages(:korean))
    create_voice_message(room: @room, sender: @sender)
  end

  test "Room 화면에 신고 버튼과 차단 버튼을 모두 표시한다" do
    # 호스트와 수신자 모두 현재 대화에서 바로 신고·차단할 수 있어야 한다.
    participants = [ @sender, @recipient ]

    participants.each do |user|
      as_user(user) do
        visit room_path(@room)

        # 별도 안전 화면으로 이동해야 차단 버튼을 찾는 구조를 방지한다.
        # 두 버튼 모두 현재 Room 화면에서 사용자에게 보여야 한다.
        assert_button "Report user"
        assert_button "Block user"
        assert_current_path room_path(@room)

        # 버튼을 표시하는 것만으로 신고나 차단이 실행되면 안 된다.
        assert_empty @room.content_reports
        assert_not UserBlock.exists_between?(@sender, @recipient)
      end
    end
  end

  test "사용자가 아동 안전 우려를 앱 안에서 신고할 수 있다" do
    as_user(@recipient) do
      visit room_path(@room)
      click_link "Report or block"
      select "Child sexual abuse or exploitation", from: "Reason"
      fill_in "Additional details (optional)", with: "They requested sexual voice messages from a child."
      click_button "Submit report"

      assert_text "Report submitted. Our safety team will review it."
    end

    report = @room.content_reports.sole
    assert_equal @recipient.id, report.reporter_id
    assert_equal @sender.id, report.reported_user_id
    assert_equal "child_exploitation", report.reason
    assert report.pending?
  end

  test "사용자가 상대방을 차단할 수 있다" do
    as_user(@recipient) do
      visit room_path(@room)
      click_link "Report or block"
      accept_confirm do
        click_button "Block user"
      end

      assert_text "User blocked."
    end

    assert UserBlock.exists?(blocker: @recipient, blocked: @sender)
  end

  test "운영자가 신고 목록에서 내용을 검토하고 처리 결과를 저장할 수 있다" do
    # 사용자가 제출한 기록이 별도의 수동 등록 없이 운영자 목록에 나타나야 한다.
    as_user(@recipient) do
      visit room_safety_path(@room)
      select "Harassment or bullying", from: "Reason"
      fill_in "Additional details (optional)", with: "They repeatedly sent abusive voice messages."
      click_button "Submit report"
      assert_text "Report submitted. Our safety team will review it."
    end

    report = @room.content_reports.sole

    as_user(@admin) do
      visit "/admin/content_reports"
      within "[data-testid='content-report'][data-report-id='#{report.id}']" do
        assert_text @sender.display_name
        assert_text @recipient.display_name
        assert_text "Harassment or bullying"
        assert_text "Pending review"
        click_link "Review report"
      end

      assert_current_path "/admin/content_reports/#{report.id}"
      assert_text "They repeatedly sent abusive voice messages."
      assert_selector "audio"

      fill_in "Resolution", with: "Reviewed the report and warned the violating user."
      select "Review completed", from: "Status"
      click_button "Save review"

      assert_text "Report reviewed."
    end

    assert report.reload.reviewed?
    assert_equal @admin.id, report.reviewed_by_id
    assert_not_nil report.reviewed_at
    assert_equal "Reviewed the report and warned the violating user.", report.resolution
  end

  test "앱 내 안전 화면에서 공개 정책과 연락처에 접근할 수 있다" do
    as_user(@recipient) do
      visit room_safety_path(@room)

      # 신고 화면에서 정책과 실제 연락처를 쉽게 찾을 수 있어야 한다.
      assert_selector "a[href^='mailto:']"
      click_link "Child Safety Standards"

      assert_current_path child_safety_path
      assert_text "Child Sexual Abuse and Exploitation"
      assert_text "at least 18 years old"
      assert_selector "a[href^='mailto:']"
    end
  end

  test "운영자가 신고 대상 계정을 정지하면 기존 브라우저에서도 이용할 수 없다" do
    report = @room.content_reports.create!(reporter: @recipient, reported_user: @sender, reason: "harassment", details: "Report of repeated abusive messages")

    as_user(@admin) do
      visit "/admin/content_reports/#{report.id}"
      within "[data-testid='reported-user']" do
        click_button "Suspend user"
      end
      assert_text "User suspended."
    end

    assert_not_nil @sender.reload.suspended_at

    # 정지 전부터 로그인된 사용자의 브라우저로 다시 접근한다.
    as_user(@sender) do
      visit root_path
      assert_text "Your account is suspended."
      assert_no_button "Drop a voice"
    end
  end

  private

  def as_user(user)
    using_session("safety_workflow_#{user.id}") do
      yield
    end
  end

  def complete_onboarding(user)
    native = user.native_language.label
    learning = user.learning_language.label
    user.update!(native_language: nil, learning_language: nil)

    # 각 브라우저 세션에서 정상 온보딩을 마쳐 테스트 사용자를 준비한다.
    # 이후 신고·차단 테스트가 미완료 사용자 때문에 실패하지 않게 한다.
    as_user(user) do
      sign_in(user: user)
      select native, from: "user_native_language_id"
      select learning, from: "user_learning_language_id"
      # 이 테스트의 정상 완료 조건에는 필수 이용정책 동의도 포함한다.
      check "user_community_rules_accepted"
      fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
      page.execute_script(<<~JS)
        navigator.mediaDevices.getUserMedia = async () => ({
          getTracks() { return [{ stop() {} }]; }
        });
      JS
      click_button "Allow microphone"
      assert_text "Microphone access allowed"
      click_button "Continue"
      assert_current_path root_path, wait: 5
    end
  end
end
