require "test_helper"
require_relative "../test_helpers/voice_test_helper"

class SafetyAccessTest < ActionDispatch::IntegrationTest
  include VoiceTestHelper

  setup do
    @sender = users(:english_native)
    @recipient = users(:korean_native)
    @admin = users(:japanese_native)
    @admin.update!(admin: true, native_language: languages(:korean), learning_language: languages(:english))

    # 모델에 가짜 완료 값을 넣는 대신 정상 온보딩 요청으로 사용자를 준비한다.
    # 따라서 이후 접근 거부가 미완료 온보딩 때문에 발생하는 것을 방지한다.
    complete_onboarding(@sender)
    complete_onboarding(@recipient)
    complete_onboarding(@admin)

    @room = Room.create!(host: @sender, opponent: @recipient, language: languages(:korean))
    @message = create_voice_message(room: @room, sender: @sender)
  end

  test "r_신고 사유에 아동 성착취와 미성년 사용자 의심을 제공한다" do
    sign_in_as(@recipient)
    get room_safety_path(@room)

    assert_response :success
    assert_select "select option[value='child_exploitation']", text: "Child sexual abuse or exploitation"
    assert_select "select option[value='underage_user']", text: "Suspected underage user"
  end

  test "아동 안전 신고를 저장하고 신고자와 대상을 서버에서 결정한다" do
    sign_in_as(@recipient)

    # 요청자가 신고자와 대상을 위조해도 대화 참여자를 기준으로 저장한다.
    assert_difference "ContentReport.count", 1 do
      post room_report_path(@room), params: {
        content_report: {
          reason: "child_exploitation",
          details: "They requested sexual voice messages from a child.",
          reporter_id: @admin.id,
          reported_user_id: @admin.id
        }
      }
    end

    report = @room.content_reports.sole
    assert_equal @recipient.id, report.reporter_id
    assert_equal @sender.id, report.reported_user_id
    assert_equal "child_exploitation", report.reason
    assert_equal "They requested sexual voice messages from a child.", report.details
    assert report.pending?
  end

  test "대화 참여자가 아닌 사용자는 신고할 수 없다" do
    sign_in_as(@admin)

    assert_no_difference "ContentReport.count" do
      post room_report_path(@room), params: { content_report: { reason: "harassment", details: "Report of another user's conversation" } }
    end

    assert_response :not_found
  end

  test "r_차단하면 양방향 수신 후보에서 제외한다" do
    sign_in_as(@recipient)
    post room_block_path(@room)

    assert UserBlock.exists?(blocker: @recipient, blocked: @sender)

    # 양쪽 모두 같은 언어를 사용하고 최근 접속했으므로 차단으로 제외되어야 한다.
    @sender.update!(last_active_at: Time.current)
    @recipient.update!(last_active_at: Time.current)
    pairs = [ [ @sender, @recipient ], [ @recipient, @sender ] ]

    pairs.each do |sender, excluded|
      candidates = VoiceRecipientSelector.recipients(sender: sender, language: languages(:korean))
      assert_not_includes candidates.pluck(:id), excluded.id
    end
  end

  test "r_차단 후에는 이전 음성 주소로도 상대 음성을 읽을 수 없다" do
    @message.update!(moderation_status: "approved")
    sign_in_as(@recipient)
    get audio_room_voice_message_path(@room, @message)

    # 차단 전에 정상 재생되는 음성이어야 접근 차단을 의미 있게 검증할 수 있다.
    assert_response :success
    assert_equal voice_audio, response.body

    post room_block_path(@room)
    get audio_room_voice_message_path(@room, @message)

    assert_response :not_found
  end

  test "r_차단하면 양쪽 모두 직접 답장 API로도 전송할 수 없다" do
    sign_in_as(@recipient)
    post room_block_path(@room)
    actors = [ @sender, @recipient ]

    actors.each do |actor|
      # 각 사용자에게 정상 답장 차례를 만들어 차례 검사에만 의존하지 않는다.
      create_voice_message(room: @room, sender: @room.opponent_for(actor))
      assert @room.reload.can_reply?(actor)
      sign_in_as(actor)

      assert_no_difference "VoiceMessage.count" do
        post room_voice_messages_path(@room), params: { voice_message: { audio: voice_upload, duration_ms: 2_000 } }
      end

      assert_includes [ 403, 404, 409, 422 ], response.status
    end
  end

  test "r_나이 미확인 사용자와 정지 사용자는 수신 후보에서 제외한다" do
    # setup의 온보딩 요청은 다른 User 객체로 DB에 나이 확인 시각을 저장한다.
    # @recipient는 아직 nil을 기억하므로 먼저 최신 값을 읽어야 한다.
    # reload 없이 nil을 대입하면 Rails가 변경으로 인식하지 않아 DB에
    # 나이 확인 시각이 남고, 나이 미확인 사용자라는 준비 조건이 성립하지 않는다.
    @recipient.reload.update!(age_confirmed_at: nil, last_active_at: Time.current)
    @admin.update!(suspended_at: Time.current, last_active_at: Time.current)

    candidates = VoiceRecipientSelector.recipients(sender: @sender, language: languages(:korean))

    assert_not_includes candidates.pluck(:id), @recipient.id
    assert_not_includes candidates.pluck(:id), @admin.id
  end

  test "r_일반 사용자는 운영자 신고 목록과 처리 API를 사용할 수 없다" do
    report = create_report
    sign_in_as(@recipient)

    get "/admin/content_reports"
    assert_response :forbidden

    patch "/admin/content_reports/#{report.id}", params: { content_report: { status: "dismissed", resolution: "Unauthorized dismissal" } }

    assert_response :forbidden
    assert report.reload.pending?
  end

  test "r_운영자는 신고와 음성 증거를 확인하고 처리 기록을 남긴다" do
    report = create_report
    sign_in_as(@admin)
    get "/admin/content_reports/#{report.id}"

    assert_response :success
    assert_select "[data-testid='reporter']", text: @recipient.display_name
    assert_select "[data-testid='reported-user']", text: @sender.display_name
    assert_select "[data-testid='report-details']", text: report.details
    assert_select "audio"

    # 상대방에게 비공개인 검토 대기 음성도 담당 운영자는 증거로 재생할 수 있다.
    get "/admin/voice_messages/#{@message.id}/audio"
    assert_response :success
    assert_equal voice_audio, response.body
    assert_includes response.headers["Cache-Control"], "no-store"

    patch "/admin/content_reports/#{report.id}", params: {
      content_report: { status: "actioned", resolution: "Blocked access to the violating voice message and suspended the account." }
    }

    assert_response :redirect
    assert report.reload.actioned?
    assert_equal @admin.id, report.reviewed_by_id
    assert_not_nil report.reviewed_at
    assert_equal "Blocked access to the violating voice message and suspended the account.", report.resolution
  end

  test "r_아동 안전 신고는 일반 신고보다 운영자 목록 상단에 표시한다" do
    # 오래된 아동 안전 신고가 최신 일반 신고 뒤에 묻히지 않도록 한다.
    urgent = @room.content_reports.create!(reporter: @recipient, reported_user: @sender, reason: "child_exploitation", details: "Child safety concern")
    urgent.update_columns(created_at: 2.days.ago)
    ordinary = create_report
    sign_in_as(@admin)

    get "/admin/content_reports"

    assert_response :success
    assert_select "[data-testid='content-report']" do |rows|
      assert_equal urgent.id.to_s, rows.first["data-report-id"]
      assert rows.any? { |row| row["data-report-id"] == ordinary.id.to_s }
    end
  end

  test "r_처리 내용을 남기지 않은 신고는 종결할 수 없다" do
    report = create_report
    sign_in_as(@admin)

    patch "/admin/content_reports/#{report.id}", params: { content_report: { status: "actioned", resolution: "" } }

    assert_response :unprocessable_entity
    assert report.reload.pending?
  end

  test "r_운영자가 계정을 정지하면 기존 로그인 세션으로도 전송할 수 없다" do
    # 정상 상태에서는 전송자에게 답장 차례가 있음을 확인한다.
    create_voice_message(room: @room, sender: @recipient)
    assert @room.reload.can_reply?(@sender)
    user_session = open_session
    user_session.sign_in_as(@sender)
    sign_in_as(@admin)

    post "/admin/users/#{@sender.id}/suspension"

    assert_response :redirect
    assert_not_nil @sender.reload.suspended_at

    assert_no_difference [ "VoiceDrop.count", "VoiceMessage.count", "Room.count" ] do
      user_session.post voice_drop_path, params: {
        room_language_id: languages(:korean).id,
        request_key: "suspended-account",
        voice_message: { audio: voice_upload, duration_ms: 2_000 }
      }
    end

    assert_equal 403, user_session.response.status

    user_session.get root_path
    assert_equal 403, user_session.response.status

    user_session.get audio_room_voice_message_path(@room, @message)
    assert_equal 403, user_session.response.status

    assert_no_difference "VoiceMessage.count" do
      user_session.post room_voice_messages_path(@room), params: { voice_message: { audio: voice_upload, duration_ms: 2_000 } }
    end
    assert_equal 403, user_session.response.status
  end

  test "r_일반 사용자는 다른 사용자를 운영자 권한으로 정지할 수 없다" do
    sign_in_as(@recipient)
    post "/admin/users/#{@sender.id}/suspension"

    assert_response :forbidden
    assert_nil @sender.reload.suspended_at
  end

  private

  def complete_onboarding(user)
    native_id = user.native_language_id
    learning_id = user.learning_language_id
    user.update!(native_language: nil, learning_language: nil)
    session = open_session
    session.sign_in_as(user)
    session.patch onboarding_path, params: {
      user: {
        native_language_id: native_id,
        learning_language_id: learning_id,
        date_of_birth: Date.current.years_ago(20).iso8601,
        microphone_confirmed: "1"
      }
    }
    assert_equal 303, session.response.status
    assert_equal root_url, session.response.location
  end

  def create_report
    @room.content_reports.create!(reporter: @recipient, reported_user: @sender, reason: "harassment", details: "They repeatedly sent abusive voice messages.")
  end
end
