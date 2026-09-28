module VoiceMatching
  class CandidateQuery
    def initialize(sender:, language:)
      @sender, @language = sender, language
    end

    def call
      engaged = Room.involving(@sender).where(language: @language).where.not(status: :deleted)
      User.where(mother_language: @language).or(User.where(learning_language: @language))
        .where.not(id: @sender.id)
        .where.not(mother_language_id: nil).where.not(learning_language_id: nil)
        .where("mother_language_id <> learning_language_id")
        .where.not(id: UserBlock.where(blocker: @sender).select(:blocked_id))
        .where.not(id: UserBlock.where(blocked: @sender).select(:blocker_id))
        .where.not(id: engaged.where(user: @sender).select(:opponent_id))
        .where.not(id: engaged.where(opponent: @sender).select(:user_id))
    end
  end
end
