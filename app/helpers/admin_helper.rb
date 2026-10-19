module AdminHelper
  def admin_time(value)
    value ? value.in_time_zone("Asia/Seoul").strftime("%Y.%m.%d %H:%M") : "—"
  end

  def admin_streak(dates)
    return 0 unless [Date.current, Date.yesterday].include?(dates.first)
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
