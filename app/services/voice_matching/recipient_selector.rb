module VoiceMatching
  # The only ranking policy. Both language tabs pass the same language-based inputs.
  # Weights are heuristics, not calibrated probabilities; tune against 24-hour reply rates.
  class RecipientSelector
    attr_reader :config

    def initialize(sender:, language:, random: Random.new, now: Time.current,
      config: Rails.application.config_for(:voice_matching))
      @sender, @language, @random, @now, @config = sender, language, random, now, config
    end

    def call(limit: config.fetch(:recipient_limit))
      selected = []
      CandidateQuery.new(sender: @sender, language: @language).call
        .find_in_batches(batch_size: config.fetch(:candidate_batch_size)) do |users|
        stats = RecipientStats.new(users, now: @now, config: config).call
        users.each do |user|
          values = stats.fetch(user.id)
          next if values[:pending_conversations] >= config.fetch(:max_pending_conversations)
          key = -Math.log(1.0 - @random.rand) / weight(values)
          selected << [key, user]
          selected.sort_by!(&:first)
          selected.pop if selected.size > limit
        end
      end
      selected.map(&:last)
    end

    def weight(values)
      hours = values[:hours_since_active]
      recency = hours ? Math.exp(-hours / config.fetch(:activity_decay_hours).to_f) : 0.0
      successes = config.fetch(:response_prior_successes).to_f
      failures = config.fetch(:response_prior_failures).to_f
      response = (values[:replied_within_24h] + successes) / (values[:matured_deliveries] + successes + failures)
      score = blend(recency, :recency_floor) * blend(response, :response_floor) *
        blend(values[:availability], :availability_floor)
      load = (1.0 + values[:pending_conversations])**config.fetch(:pending_penalty_exponent)
      exposure = 1.0 + values[:deliveries_last_24h] / config.fetch(:exposure_penalty_scale).to_f
      [score / (load * exposure), 0.0001].max
    end

    private

    def blend(value, key)
      floor = config.fetch(key)
      floor + (1.0 - floor) * value
    end
  end
end
