require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @deleter = users(:one)
    @recipient = User.create!(
      email_address: "room-recipient@example.com",
      password: "password"
    )
    @room = Room.create!(
      user: @deleter,
      opponent: @recipient,
      last_sender: @recipient,
      last_message_at: Time.current
    )
    @message = @room.voice_messages.build(sender: @recipient, duration_ms: 2_000)
    @message.audio.attach(fixture_file_upload("sample.webm", "audio/webm"))
    @message.save!
    sign_in_as @deleter
  end

  test "deleting a room removes its voice and hides it from the deleter" do
    assert_difference [ "VoiceMessage.count", "ActiveStorage::Blob.count" ], -1 do
      delete room_path(@room)
    end

    assert_redirected_to rooms_path
    assert @room.reload.deleted?
    assert_equal @deleter.id, @room.deleted_by_id
    assert_not ActiveStorage::Attachment.exists?(record: @message)
    assert_not User.find(@deleter.id).rooms.where(id: @room.id).where.not(status: :deleted).exists?

    get rooms_path
    assert_no_match @recipient.name, response.body
    get room_path(@room)
    assert_redirected_to rooms_path
  end

  test "the other participant sees the conversation-ended notice" do
    delete room_path(@room)
    sign_out
    sign_in_as @recipient

    get rooms_path
    assert_response :success
    assert_select "a[href='#{room_path(@room)}']"
    assert_select "p", text: /no longer wants to continue this conversation/

    get room_path(@room)
    assert_response :success
    assert_select "audio[src]", count: 0
    assert_select "[role='status']", text: /no longer wants to continue this conversation/
    assert_select "button[aria-label='Delete conversation']", count: 1
    assert_select "form[data-action='submit->confirmation-modal#submit']", count: 1
    assert_select "form[data-turbo-confirm]", count: 0
    assert_select "[data-confirmation-modal-target='dialog'][hidden]", count: 1
    assert_select "[data-confirmation-modal-target='confirmButton']", text: "Delete", count: 1

    delete room_path(@room)
    assert_redirected_to rooms_path
    assert @room.reload.dismissed_by_id == @recipient.id
    get rooms_path
    assert_no_match @deleter.name, response.body
  end
end
