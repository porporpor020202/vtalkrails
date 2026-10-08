require "test_helper"
require_relative "../test_helpers/voice_test_helper"

class OnboardingAccessTest < ActionDispatch::IntegrationTest
  include VoiceTestHelper

  setup do
    @user = users(:english_native)
    @user.update!(native_language: nil, learning_language: nil)
    sign_in_as(@user)
  end

  test "r_필수 값이 빠진 직접 요청은 온보딩을 저장하지 않는다" do
    # 브라우저의 disabled 버튼을 우회해 필수 값을 하나씩 생략한다.
    # 하나의 조합이 잘못 저장되면 다음 조합을 진행하기 전에 실패해야 한다.
    required_fields = [ :native_language_id, :learning_language_id, :date_of_birth, :microphone_confirmed ]

    required_fields.each do |field|
      attributes = valid_attributes
      attributes.delete(field)

      patch onboarding_path, params: { user: attributes }

      assert_response :unprocessable_entity
      assert_nil @user.reload.native_language
      assert_nil @user.learning_language
      assert_not @user.onboarding_complete?
    end
  end

  test "r_미성년 생년월일이면 클라이언트가 성인이라고 보내도 완료하지 않는다" do
    # 나이 판정과 완료 시각은 서버가 정해야 한다.
    # 클라이언트가 보낸 adult 값이나 완료 시각을 그대로 저장하지 않는다.
    attributes = valid_attributes.merge(
      date_of_birth: (Date.current.years_ago(18) + 1.day).iso8601,
      adult: "1",
      age_confirmed_at: Time.current.iso8601,
      onboarding_completed_at: Time.current.iso8601
    )

    patch onboarding_path, params: { user: attributes }

    assert_response :unprocessable_entity
    assert_nil @user.reload.native_language
    assert_nil @user.learning_language
    assert_not @user.onboarding_complete?
  end

  test "r_미래 날짜와 잘못된 날짜는 서버에서도 거부한다" do
    dates = [ Date.tomorrow.iso8601, "not-a-date", "2000-02-30" ]

    dates.each do |date|
      patch onboarding_path, params: { user: valid_attributes.merge(date_of_birth: date) }

      assert_response :unprocessable_entity
      assert_not @user.reload.onboarding_complete?
    end
  end

  test "r_마이크 미확인 값을 보내면 서버에서도 완료하지 않는다" do
    # 이 값은 기기 권한을 증명하는 인증서가 아니라 클라이언트의 확인 결과다.
    # 최소한 누락과 명시적인 false 값은 서버에서 거부해야 한다.
    values = [ "0", false, "false" ]

    values.each do |value|
      patch onboarding_path, params: { user: valid_attributes.merge(microphone_confirmed: value) }

      assert_response :unprocessable_entity
      assert_not @user.reload.onboarding_complete?
    end
  end

  test "r_같은 언어 두 개로는 서버에서도 완료할 수 없다" do
    patch onboarding_path, params: { user: valid_attributes.merge(native_language_id: languages(:english).id) }

    assert_response :unprocessable_entity
    assert_not @user.reload.onboarding_complete?
  end

  test "r_정상 요청으로 완료하면 나이 확인과 완료 시각을 서버에서 기록한다" do
    # 임의로 과거 시각을 전달해도 서버의 현재 시각을 기록해야 한다.
    travel_to Time.zone.local(2026, 10, 8, 12) do
      attributes = valid_attributes.merge(
        age_confirmed_at: "2000-01-01T00:00:00Z",
        onboarding_completed_at: "2000-01-01T00:00:00Z"
      )

      patch onboarding_path, params: { user: attributes }

      assert_redirected_to root_path
      assert_equal Time.current, @user.reload.age_confirmed_at
      assert_equal Time.current, @user.onboarding_completed_at
      assert @user.onboarding_complete?
    end
  end

  test "r_언어만 저장된 기존 사용자도 나이 확인 전에는 루트에 접근할 수 없다" do
    # 기존 데이터에 언어가 있다는 이유만으로 나이 확인을 건너뛰지 않는다.
    @user.update!(native_language: languages(:english), learning_language: languages(:korean))

    get root_path

    assert_redirected_to onboarding_path
    assert_not @user.reload.onboarding_complete?
  end

  test "r_미완료 사용자는 음성 전송 API를 직접 호출해도 전송할 수 없다" do
    @user.update!(native_language: languages(:english), learning_language: languages(:korean))

    # 수신 후보도 준비하여 수신자 없음 오류로 우연히 거부되지 않게 한다.
    users(:korean_native).update!(last_active_at: Time.current)

    # 정상 파일과 언어를 보내서 파일 검증 오류로 우연히 통과하지 않게 한다.
    assert_no_difference [ "VoiceDrop.count", "VoiceMessage.count", "Room.count" ] do
      post voice_drop_path, params: {
        room_language_id: languages(:korean).id,
        request_key: "incomplete-onboarding",
        voice_message: { audio: voice_upload, duration_ms: 2_000 }
      }
    end

    assert_redirected_to onboarding_path
  end

  test "r_미완료 사용자는 기존 대화의 답장과 음성 읽기도 우회할 수 없다" do
    partner = users(:korean_native)
    room = Room.create!(host: partner, opponent: @user, language: languages(:korean))
    message = create_voice_message(room: room, sender: partner)
    @user.update!(native_language: languages(:english), learning_language: languages(:korean))

    assert_no_difference "VoiceMessage.count" do
      post room_voice_messages_path(room), params: { voice_message: { audio: voice_upload, duration_ms: 2_000 } }
    end

    assert_redirected_to onboarding_path

    get audio_room_voice_message_path(room, message)

    assert_redirected_to onboarding_path
  end

  private

  def valid_attributes
    {
      native_language_id: languages(:korean).id,
      learning_language_id: languages(:english).id,
      date_of_birth: Date.current.years_ago(20).iso8601,
      microphone_confirmed: "1"
    }
  end
end
