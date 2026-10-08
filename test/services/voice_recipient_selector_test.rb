require "test_helper"
require "minitest/mock"

class VoiceRecipientSelectorTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @sender = users(:english_native)
    @room_language = languages(:korean)
    @candidate_number = 0
  end

  teardown do
    travel_back
  end

  test "r_전송 인원은 설정 파일의 값을 사용한다" do
    configured_limit = Rails.configuration.x.voice_recipient_selection.recipient_limit

    assert_not_nil configured_limit
    assert_equal configured_limit, VoiceRecipientSelector.recipient_limit
  end

  test "r_최근 접속 기간은 설정 파일의 값을 사용한다" do
    configured_window = Rails.configuration.x.voice_recipient_selection.activity_window

    assert_not_nil configured_window
    assert_equal configured_window, VoiceRecipientSelector.activity_window
  end

  test "조건에 맞는 후보 중 최근 접속순으로 설정된 인원만큼 선택한다" do
    limit = VoiceRecipientSelector.recipient_limit
    window = VoiceRecipientSelector.activity_window
    interval = window.to_f / (limit + 2)

    candidates = (limit + 1).downto(1).map do |position|
      create_candidate(last_active_at: Time.current - interval * position)
    end

    expected = candidates
      .sort_by(&:last_active_at)
      .reverse
      .first(limit)

    assert_equal expected.map(&:id), recipient_ids
  end

  test "후보가 설정된 인원보다 적으면 가능한 후보만 선택한다" do
    candidates = Array.new(VoiceRecipientSelector.recipient_limit - 1) do |index|
      create_candidate(last_active_at: Time.current - index.seconds)
    end

    assert_equal candidates.map(&:id).sort, recipient_ids.sort
  end

  test "전송 인원 설정을 바꾸면 선정 인원도 바뀐다" do
    limits = [ 2, 4 ]
    interval = VoiceRecipientSelector.activity_window.to_f / (limits.max + 2)
    candidates = Array.new(limits.max + 1) do |index|
      create_candidate(last_active_at: Time.current - interval * index)
    end

    limits.each do |limit|
      VoiceRecipientSelector.stub(:recipient_limit, limit) do
        assert_equal candidates.first(limit).map(&:id), recipient_ids
      end
    end
  end

  test "최근 접속 기간의 경계 시각에 접속한 사용자도 선택한다" do
    candidate = create_candidate(last_active_at: Time.current - VoiceRecipientSelector.activity_window)

    assert_equal [ candidate.id ], recipient_ids
  end

  test "설정된 최근 접속 기간을 벗어난 사용자는 제외한다" do
    create_candidate(last_active_at: Time.current - VoiceRecipientSelector.activity_window - 1.second)

    assert_empty recipient_ids
  end

  test "최근 접속 기간 설정을 바꾸면 후보 포함 여부도 바뀐다" do
    candidate = create_candidate(last_active_at: 4.days.ago)

    VoiceRecipientSelector.stub(:activity_window, 1.day) do
      assert_empty recipient_ids
    end

    VoiceRecipientSelector.stub(:activity_window, 7.days) do
      assert_equal [ candidate.id ], recipient_ids
    end
  end

  test "접속 기록이 없는 사용자는 제외한다" do
    create_candidate(last_active_at: nil)

    assert_empty recipient_ids
  end

  test "Say탭에서 센더가 언어를 선택하면, 그 언어를 모국어, 또는 학습언어로 들고있는 사용자가 메시지를 받는다." do
    [
      [ languages(:korean), languages(:english) ],
      [ languages(:english), languages(:korean) ]
    ].each do |native, learning|
      candidate = create_candidate(native_language: native, learning_language: learning)

      assert_equal [ candidate.id ], recipient_ids

      candidate.update!(last_active_at: nil)
    end
  end

  test "최근 접속했어도 선택 언어가 모국어와 학습 언어 어디에도 없으면 제외한다" do
    create_candidate(
      native_language: languages(:english),
      learning_language: languages(:spanish),
      last_active_at: Time.current
    )

    assert_empty recipient_ids
  end

  test "r_발신자는 최근 접속했고 언어 조건에 맞아도 리시버에서 제외한다" do
    @sender.update!(last_active_at: Time.current)

    assert_empty recipient_ids
  end

  test "한국어 학습자가 영어로 전송하면 영어 사용자를 선택한다" do
    assert_equal languages(:korean), @sender.learning_language

    @room_language = languages(:english)
    candidate = create_candidate(
      native_language: languages(:spanish),
      learning_language: languages(:english)
    )

    assert_equal [ candidate.id ], recipient_ids
  end

  test "선정된 수신자는 중복되지 않는다" do
    Array.new(VoiceRecipientSelector.recipient_limit + 1) { create_candidate }

    ids = recipient_ids

    assert_equal VoiceRecipientSelector.recipient_limit, ids.size
    assert_equal ids.uniq, ids
  end

  test "차단한 상대를 후보 수 제한 전에 제외하고 정상 상대를 매칭한다" do
    blocked = create_candidate(last_active_at: Time.current)
    available = create_candidate(last_active_at: 1.minute.ago)

    UserBlock.create!(blocker: @sender, blocked: blocked)

    # 더 최근 접속한 차단 상대를 먼저 제외해야 한다.
    # limit 이후 차단을 걸러내면 정상 상대가 있는데도 결과가 비게 된다.
    VoiceRecipientSelector.stub(:recipient_limit, 1) do
      assert_equal [ available.id ], recipient_ids
    end
  end

  test "나를 차단한 상대도 후보 수 제한 전에 제외하고 정상 상대를 매칭한다" do
    blocker = create_candidate(last_active_at: Time.current)
    available = create_candidate(last_active_at: 1.minute.ago)

    UserBlock.create!(blocker: blocker, blocked: @sender)

    # 차단 방향과 관계없이 두 사람은 다시 매칭되지 않아야 한다.
    VoiceRecipientSelector.stub(:recipient_limit, 1) do
      assert_equal [ available.id ], recipient_ids
    end
  end

  private

  def recipient_ids
    VoiceRecipientSelector.recipients(sender: @sender, language: @room_language).map(&:id)
  end

  def create_candidate(last_active_at: Time.current, native_language: languages(:english), learning_language: languages(:korean))
    @candidate_number += 1

    # 각 테스트는 접속 시각, 언어, 차단 조건을 바꿔 수신자 선정을 검증한다.
    # 나이 확인이 없으면 후보가 모두 제외되어, 제외 테스트마저 의도와 다른
    # 이유로 통과한다. 후보는 만 18세 이상 확인과 온보딩을 완료한 상태로 만든다.
    User.create!(
      oauth_provider: :google,
      oauth_uid: "voice-matching-candidate-#{@candidate_number}",
      email_address: "voice-matching-candidate-#{@candidate_number}@example.com",
      display_name: "Voice matching candidate #{@candidate_number}",
      native_language: native_language,
      learning_language: learning_language,
      last_active_at: last_active_at,
      age_confirmed_at: Time.current,
      onboarding_completed_at: Time.current
    )
  end
end
