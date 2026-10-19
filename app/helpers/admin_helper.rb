module AdminHelper
  MARKETING_EVENTS = {
    "app_open" => "앱 방문", "question_viewed" => "질문 확인", "question_translation_used" => "질문 번역 사용",
    "answer_translation_used" => "답변을 영어로 번역", "recording_started" => "녹음 시작", "recording_completed" => "기기에서 녹음 완료",
    "practice_completed" => "녹음 전송 완료", "signup" => "신규 가입", "login" => "로그인", "guest_recording_claimed" => "첫 녹음을 계정에 저장"
  }.freeze

  def marketing_event_label(name)
    MARKETING_EVENTS.fetch(name, name)
  end

  def marketing_source_label(source)
    { "direct" => "직접 방문 · 경로 알 수 없음", "app" => "앱 실행 · 설치 경로 알 수 없음" }.fetch(source, source)
  end

  def marketing_rate(count, total)
    total.positive? ? "#{(count * 100.0 / total).round(1)}%" : "—"
  end

  def admin_time(value)
    value ? value.in_time_zone("Asia/Seoul").strftime("%Y.%m.%d %H:%M") : "—"
  end

  def admin_streak(dates)
    return 0 unless [ Date.current, Date.yesterday ].include?(dates.first)
    count = 0
    expected = dates.first
    dates.each do |date|
      break unless date == expected
      count += 1
      expected -= 1
    end
    count
  end
end
