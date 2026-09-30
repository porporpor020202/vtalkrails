module VoiceMatching
  class CandidateQuery
    def initialize(sender:)
      @sender = sender
    end

    def call
      engaged = Room.involving(@sender).where.not(status: :deleted)
      User.where.not(native_language_id: nil)
        .where.not(id: @sender.id)
        .where.not(id: UserBlock.where(blocker: @sender).select(:blocked_id))
        .where.not(id: UserBlock.where(blocked: @sender).select(:blocker_id))
        .where.not(id: engaged.where(user: @sender).select(:opponent_id))
        .where.not(id: engaged.where(opponent: @sender).select(:user_id))
    end
  end
end
