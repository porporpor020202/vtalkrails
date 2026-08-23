require "test_helper"

class ModerationToolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reporter = users(:one)
    @reported_user = users(:two)
    @room = Room.create!(
      user: @reporter,
      opponent: @reported_user,
      last_sender: @reported_user,
      last_message_at: Time.current
    )
    @message = @room.voice_messages.build(sender: @reported_user, duration_ms: 2_000)
    @message.audio.attach(fixture_file_upload("sample.webm", "audio/webm"))
    @message.save!
    sign_in_as @reporter
  end

  test "participant can open the safety screen" do
    get room_safety_path(@room)

    assert_response :success
    assert_select "form[action='#{room_report_path(@room)}']"
    assert_select "form[action='#{room_block_path(@room)}']"
    assert_select "option", text: "Harassment or bullying"
  end

  test "participant can report the conversation" do
    assert_difference "ContentReport.count", 1 do
      post room_report_path(@room), params: {
        content_report: { reason: "harassment", details: "Abusive voice message" }
      }
    end

    report = ContentReport.order(:id).last
    assert_redirected_to room_safety_path(@room)
    assert_equal @reporter, report.reporter
    assert_equal @reported_user, report.reported_user
    assert_equal @room, report.room
    assert report.pending?
  end

  test "nonparticipant cannot report a conversation" do
    outsider = User.create!(email_address: "outsider@example.com", password: "password")
    sign_out
    sign_in_as outsider

    assert_no_difference "ContentReport.count" do
      post room_report_path(@room), params: { content_report: { reason: "spam" } }
    end

    assert_response :not_found
  end

  test "participant can block the other user and retain evidence" do
    assert_difference "UserBlock.count", 1 do
      post room_block_path(@room)
    end

    assert_redirected_to rooms_path
    assert UserBlock.exists?(blocker: @reporter, blocked: @reported_user)
    assert @room.reload.deleted?
    assert_equal @reporter, @room.deleted_by
    assert VoiceMessage.exists?(@message.id)
    assert ActiveStorage::Attachment.exists?(record: @message)
  end
end
