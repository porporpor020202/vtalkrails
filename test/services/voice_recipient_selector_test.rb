require "test_helper"
require "minitest/mock"

class VoiceRecipientSelectorTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @sender = users(:english_native)
    @candidate_number = 0
  end

  teardown do
    travel_back
  end

  test "전송 인원은 설정 파일의 값을 사용한다" do
    configured_limit = Rails.configuration.x.voice_recipient_selection.recipient_limit

    assert_not_nil configured_limit
    assert_equal configured_limit, VoiceRecipientSelector.recipient_limit
  end

  test "최근 접속 기간은 설정 파일의 값을 사용한다" do
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

  test "같은 모국어 사용자만 수신자로 선택한다" do
    same_language = create_candidate(native_language: languages(:english))
    create_candidate(native_language: languages(:spanish))
    create_candidate(native_language: languages(:japanese))

    assert_equal [same_language.id], recipient_ids
  end

  test "모국어를 변경하면 새로운 언어의 수신자만 선택한다" do
    english = create_candidate(native_language: languages(:english))
    spanish = create_candidate(native_language: languages(:spanish))
    assert_equal [english.id], recipient_ids

    @sender.update!(native_language: languages(:spanish))
    assert_equal [spanish.id], recipient_ids
  end

  test "발신자는 최근 접속했어도 수신자에서 제외한다" do
    @sender.update!(last_active_at: Time.current)
    assert_empty recipient_ids
  end

  test "수신을 끈 사용자와 정지된 사용자와 나이 확인이 없는 사용자는 제외한다" do
    # 언어 조건을 없애더라도 기존 수신 설정과 안전 조건은 유지해야 한다.
    opted_out = create_candidate
    opted_out.update!(receive_new_rooms: false)
    suspended = create_candidate
    suspended.update!(suspended_at: Time.current)
    unconfirmed = create_candidate
    unconfirmed.update!(age_confirmed_at: nil)
    available = create_candidate

    assert_equal [ available.id ], recipient_ids
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
    VoiceRecipientSelector.recipients(sender: @sender).map(&:id)
  end

  def create_candidate(last_active_at: Time.current, native_language: languages(:english))
    @candidate_number += 1

    # 학습 언어 없이 접속 시각, 수신 설정, 안전 조건을 바꿔 선정 결과를 검증한다.
    # 나이 확인이 없으면 후보가 모두 제외되어, 제외 테스트마저 의도와 다른
    # 이유로 통과한다. 후보는 만 18세 이상 확인과 온보딩을 완료한 상태로 만든다.
    User.create!(
      oauth_provider: :google,
      oauth_uid: "voice-matching-candidate-#{@candidate_number}",
      email_address: "voice-matching-candidate-#{@candidate_number}@example.com",
      display_name: "Voice matching candidate #{@candidate_number}",
      native_language: native_language,
      last_active_at: last_active_at,
      age_confirmed_at: Time.current,
      onboarding_completed_at: Time.current
    )
  end
end
