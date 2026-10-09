require "application_system_test_case"
require "base64"
require_relative "../test_helpers/voice_test_helper"

class RoomSafetyTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @host = users(:english_native)
    @recipient = users(:korean_native)

    @room = Room.create!(host: @host, opponent: @recipient)
    create_voice_message(room: @room, sender: @host)
    create_voice_message(room: @room, sender: @recipient)

    # 양쪽 모두 Room index에서 볼 수 있는, 답장을 주고받은 방이다.
    # 호스트에게 원래 보이지 않던 방을 삭제 결과로 오인하지 않는다.
  end

  %i[host recipient].each do |role|
    test "#{role}가 삭제를 취소하면 양쪽 Room과 음성을 유지한다" do
      actor = instance_variable_get("@#{role}")

      as_user(actor) do
        visit room_path(@room)

        # 복구 불가 문구가 포함된 확인 창을 취소한다.
        dismiss_confirm(delete_confirmation) do
          click_button "Delete room"
        end

        assert_current_path room_path(@room)
        assert_selector "main article audio[controls]", count: 2
      end

      [ @host, @recipient ].each do |user|
        as_user(user) do
          assert_room_listed
          visit room_path(@room)
          assert_selector "main article audio[controls]", count: 2
        end
      end

      assert_equal 2, @room.voice_messages.count
    end

    test "#{role}가 삭제하면 본인 목록에서 사라지고 상대방에게 나감 안내를 표시한다" do
      actor = instance_variable_get("@#{role}")
      partner = actor == @host ? @recipient : @host

      # 삭제 전에 알고 있던 음성 주소도 삭제 후 접근할 수 없어야 한다.
      audio_url = audio_room_voice_message_path(
        @room, @room.voice_messages.order(:id).first
      )

      as_user(actor) do
        assert_room_listed
        visit room_path(@room)
        delete_room

        # 확인을 승인하면 바로 index로 이동한다.
        assert_current_path rooms_path, ignore_query: true
        assert_room_not_listed

        # 새로 방문하거나 직접 주소를 입력해도 복구되지 않는다.
        visit room_path(@room)
        assert_no_selector "main article audio[controls]"
        assert_room_not_listed
        assert_audio_unavailable(audio_url)
      end

      as_user(partner) do
        # 상대방에게는 삭제된 대화가 목록에 남아 있어야 한다.
        assert_room_listed
        find(room_link).click

        assert_selector '[role="dialog"]', text: "Your partner has left the conversation."
        assert_no_selector "main article audio[controls]"
        assert_no_button "Reply with voice"
        assert_audio_unavailable(audio_url)

        # 상대방도 직접 삭제해야 자신의 목록에서 사라진다.
        close_status_dialog
        delete_room

        assert_current_path rooms_path, ignore_query: true
        assert_room_not_listed
      end

      # 상대방의 삭제가 최초 삭제자의 목록에 방을 다시 나타내면 안 된다.
      as_user(actor) { assert_room_not_listed }
    end

    test "#{role}가 상대방을 차단하면 양방향 매칭에서 제외한다" do
      actor = instance_variable_get("@#{role}")
      partner = actor == @host ? @recipient : @host

      as_user(actor) do
        visit room_path(@room)
        click_link "Report or block"

        accept_confirm do
          click_button "Block user"
        end

        assert_text "User blocked."
      end

      assert UserBlock.exists?(blocker: actor, blocked: partner)

      # 두 사람 모두 같은 언어의 최근 접속자로 만들어,
      # 언어나 접속 기간 때문에 매칭에서 제외되는 상황을 방지한다.
      [ actor, partner ].each do |user|
        user.update!(last_active_at: Time.current)
      end

      # 방금 차단한 상대를 제외하는지 양방향으로 확인한다.
      [ [ actor, partner ], [ partner, actor ] ].each do |sender, excluded|
        candidates = VoiceRecipientSelector.recipients(sender: sender)
        assert_not_includes candidates.map(&:id), excluded.id
      end
    end

    test "#{role}가 신고하면 사유를 저장하고 자동 차단하며 양쪽에 검토 안내를 표시한다" do
      reporter = instance_variable_get("@#{role}")
      reported = reporter == @host ? @recipient : @host

      as_user(reporter) do
        submit_report
        assert_selector '[role="dialog"]', text: "Your report has been submitted and is under review."
      end

      report = @room.content_reports.sole
      assert_equal reporter, report.reporter
      assert_equal reported, report.reported_user
      assert_equal "harassment", report.reason
      assert_equal "They repeatedly sent abusive voice messages.", report.details
      assert report.pending?
      assert UserBlock.exists?(blocker: reporter, blocked: reported)

      # 신고자는 물론 상대방이 방에 들어왔을 때도 같은 상태를 보여준다.
      [ reporter, reported ].each do |user|
        as_user(user) do
          visit room_path(@room)
          assert_selector '[role="dialog"]', text: "Your report has been submitted and is under review."
          assert_no_button "Reply with voice"
        end
      end
    end
  end

  test "Room에는 개별 voice를 삭제하는 버튼이 없다" do
    [ @host, @recipient ].each do |user|
      as_user(user) do
        visit room_path(@room)

        # Room 전체 삭제만 제공한다.
        # 메시지별 삭제 버튼이나 삭제 링크는 제공하지 않는다.
        assert_button "Delete room"
        assert_no_button "Delete voice"
        assert_no_link "Delete voice"
        assert_no_selector "main article button", text: /delete/i
        assert_no_selector "main article a", text: /delete/i
      end
    end
  end

  %i[host recipient].each do |role|
    test "상대방이 나간 후 #{role}는 전송 API를 직접 호출해도 음성을 보낼 수 없다" do
      sender = instance_variable_get("@#{role}")
      partner = sender == @host ? @recipient : @host

      # 전송자가 정상 상태에서는 답장할 수 있는 순서로 준비한다.
      # 기존의 '답장 차례가 아님' 검사로 우연히 통과하면 안 된다.
      create_voice_message(room: @room, sender: partner)
      assert @room.reload.can_reply?(sender)

      as_user(partner) do
        visit room_path(@room)
        delete_room
        assert_current_path rooms_path, ignore_query: true
      end

      as_user(sender) do
        visit room_path(@room)
        assert_selector '[role="dialog"]', text: "Your partner has left the conversation."

        assert_no_difference "VoiceMessage.count" do
          result = send_voice_directly
          assert_includes [ 403, 404, 409, 422 ], result.fetch("status")
        end
      end
    end

    test "신고 후 #{role}는 전송 API를 직접 호출해도 음성을 보낼 수 없다" do
      sender = instance_variable_get("@#{role}")
      partner = sender == @host ? @recipient : @host

      # 신고 전에 전송자가 답장할 차례임을 먼저 확인한다.
      create_voice_message(room: @room, sender: partner)
      assert @room.reload.can_reply?(sender)

      as_user(@host) do
        submit_report
        assert_selector '[role="dialog"]', text: "Your report has been submitted and is under review."
      end

      as_user(sender) do
        visit room_path(@room)
        assert_selector '[role="dialog"]', text: "Your report has been submitted and is under review."

        # UI를 우회한 요청에서도 신고 상태를 검사해야 한다.
        assert_no_difference "VoiceMessage.count" do
          result = send_voice_directly
          assert_includes [ 403, 404, 409, 422 ], result.fetch("status")
        end
      end
    end
  end

  test "신고가 접수되면 운영진 신고 목록에 사유와 대상이 자동으로 표시된다" do
    as_user(@host) do
      submit_report
      assert_selector '[role="dialog"]', text: "Your report has been submitted and is under review."
    end

    # 별도 등록 작업 없이 운영진이 접수된 신고를 확인할 수 있어야 한다.
    admin = users(:japanese_native)
    admin.update!(admin: true)

    as_user(admin) do
      visit "/admin/content_reports"

      # 이 경로와 화면은 새로 제안하는 운영진 신고 목록이다.
      # 신고 대상, 신고자, 구체적인 사유가 한 기록 안에 표시되어야 한다.
      within '[data-testid="content-report"]' do
        assert_text @host.display_name
        assert_text @recipient.display_name
        assert_text "Harassment or bullying"
        assert_text "They repeatedly sent abusive voice messages."
        assert_text "Pending review"
      end
    end
  end

  private

  def as_user(user)
    using_session("room_safety_#{user.id}") do
      sign_in(user: user)
      yield
    end
  end

  def room_link
    "main a[href='#{room_path(@room)}']"
  end

  def assert_room_listed
    visit rooms_path
    assert_selector room_link
  end

  def assert_room_not_listed
    visit rooms_path
    assert_no_selector room_link
  end

  # 앱에서 제공하는 확인창과 상태 안내는 영어로 검증한다.
  # 테스트 이름과 설명 주석의 한국어는 앱에 표시되는 문구가 아니다.
  def delete_confirmation
    "Delete this room? This cannot be undone."
  end

  def delete_room
    accept_confirm(delete_confirmation) do
      click_button "Delete room"
    end
  end

  def close_status_dialog
    within '[role="dialog"]' do
      click_button "OK"
    end
    assert_no_selector '[role="dialog"]'
  end

  # 신고 입력 내용도 영어로 작성해 사용자 화면과 운영진 목록에서
  # 같은 내용이 그대로 보존되는지 확인한다.
  def submit_report
    visit room_path(@room)
    click_link "Report or block"
    select "Harassment or bullying", from: "Reason"
    fill_in "Additional details (optional)", with: "They repeatedly sent abusive voice messages."
    click_button "Submit report"
  end

  def assert_audio_unavailable(url)
    result = page.evaluate_async_script(<<~JS, url)
      const done = arguments[arguments.length - 1];

      fetch(arguments[0], {
        credentials: "same-origin",
        cache: "no-store"
      }).then(response => done({
        status: response.status,
        content_type: response.headers.get("content-type") || ""
      }));
    JS

    assert_includes [ 403, 404, 410 ], result.fetch("status")
    refute result.fetch("content_type").start_with?("audio/")
  end

  def send_voice_directly
    # 실제 WAV 파일을 전송해 유효하지 않은 파일 때문에 거부되지 않게 한다.
    # 브라우저의 로그인 쿠키와 CSRF 토큰을 사용하여 정상 요청과 동일하게 보낸다.
    page.evaluate_async_script(
      <<~JS,
        const url = arguments[0];
        const encodedAudio = arguments[1];
        const done = arguments[arguments.length - 1];

        const bytes = Uint8Array.from(
          atob(encodedAudio), character => character.charCodeAt(0)
        );

        const form = new FormData();
        form.append(
          "voice_message[audio]",
          new Blob([bytes], { type: "audio/wav" }),
          "voice.wav"
        );
        form.append("voice_message[duration_ms]", "2000");

        fetch(url, {
          method: "POST",
          credentials: "same-origin",
          headers: {
            "X-CSRF-Token":
              document.querySelector('meta[name="csrf-token"]').content,
            "Accept": "application/json"
          },
          body: form
        }).then(async response => done({
          status: response.status,
          body: await response.text()
        }));
      JS
      room_voice_messages_path(@room),
      Base64.strict_encode64(voice_audio)
    )
  end
end
