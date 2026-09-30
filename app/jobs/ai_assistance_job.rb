class AiAssistanceJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound

  def perform(id)
    assistance = AiAssistance.find(id)
    return unless AiAssistance.where(id: id, status: "pending").update_all(status: "processing", updated_at: Time.current) == 1

    unless assistance.user.vip? && assistance.accessible? && assistance.current_turn?
      assistance.update!(status: "failed")
      return
    end

    result = Ai::Assistant.new(assistance).call
    assistance.reload
    assistance.update!(result: result, status: "completed")
  rescue StandardError => error
    AiAssistance.where(id: id).update_all(status: "failed", updated_at: Time.current)
    Rails.logger.warn("AI assistance #{id} failed: #{error.class.name}")
  end
end
