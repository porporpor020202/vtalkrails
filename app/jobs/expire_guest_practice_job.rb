class ExpireGuestPracticeJob < ApplicationJob
  def perform(id)
    practice = DailyPractice.find_by(id: id)
    practice&.with_lock do
      practice.destroy! if practice.user_id.nil?
    end
  end
end
