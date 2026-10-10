class VoiceHelperSetting < ApplicationRecord
  # Reuse the application's stable secret with a dedicated derivation salt.
  # No new encryption secret needs to be configured to save keys in admin.
  encrypts :gemini_api_key, :openai_api_key, :groq_api_key,
    key_provider: ActiveRecord::Encryption::KeyProvider.new(
      ActiveRecord::Encryption::Key.new(Rails.application.key_generator.generate_key("voice-helper-api-keys", 32))
    )

  # Standard paid API prices checked on 2026-10-10. Rates are USD per
  # million tokens, or per audio minute. This is a forecast, not billing data.
  MODELS = {
    "gemini-2.5-flash-lite" => {
      name: "Gemini 2.5 Flash-Lite", provider: :gemini,
      text_input: 0.10, audio_input: 0.30, output: 0.40,
      description: "Legacy model. Google no longer offers access to new users."
    },
    "gemini-3.5-flash-lite" => {
      name: "Gemini 3.5 Flash-Lite", provider: :gemini,
      text_input: 0.30, audio_input: 0.30, output: 2.50,
      description: "One request: recorded speech to English. Newer Flash-Lite model."
    },
    "openai-mini" => {
      name: "OpenAI Mini Transcribe + GPT-6 Luna", provider: :openai,
      transcription_model: "gpt-4o-mini-transcribe", audio_minute: 0.003,
      text_input: 0.10, output: 0.50,
      description: "Two requests: transcribe, then generate English."
    },
    "openai-transcribe" => {
      name: "OpenAI GPT-Transcribe + GPT-6 Luna", provider: :openai,
      transcription_model: "gpt-transcribe", audio_minute: 0.0045,
      text_input: 0.10, output: 0.50,
      description: "Two requests with OpenAI's recommended file transcription model."
    },
    "groq-turbo" => {
      name: "Groq Whisper Turbo + GPT-6 Luna", provider: :groq,
      transcription_model: "whisper-large-v3-turbo", audio_minute: 0.04 / 60,
      text_input: 0.10, output: 0.50,
      description: "Two providers. Audio has a 10-second minimum charge."
    }
  }.freeze

  validates :model_key, inclusion: { in: MODELS.keys }
  validates :prompt, presence: true, length: { maximum: 10_000 }
  validates :estimated_users, :daily_uses, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1_000_000 }
  validates :audio_seconds, numericality: { only_integer: true, in: 1..30 }
  validates :usd_to_krw, numericality: { greater_than: 0, less_than_or_equal_to: 100_000 }

  def self.current
    find_by(id: 1) || create_or_find_by!(id: 1)
  end

  def self.api_key(provider)
    current.public_send("#{provider}_api_key").presence ||
      ENV["#{provider.to_s.upcase}_API_KEY"].presence || Rails.application.credentials.dig(provider, :api_key).presence
  end

  def self.missing_keys(key)
    providers = case MODELS.fetch(key).fetch(:provider)
    when :groq then [ :groq, :openai ]
    else [ MODELS.fetch(key).fetch(:provider) ]
    end
    providers.reject { |provider| api_key(provider).present? }.map { |provider| "#{provider.to_s.upcase}_API_KEY" }
  end

  def monthly_requests
    estimated_users * daily_uses * 30
  end

  def monthly_cost_usd(key)
    model = MODELS.fetch(key)
    # Assume 300 input text tokens and 30 output tokens per request.
    # Gemini audio uses 32 tokens/second. Thinking, retries, tax and hosting
    # are excluded; actual prompt/transcript sizes vary by language.
    audio_cost = if model[:provider] == :gemini
      audio_seconds * 32 * model[:audio_input] / 1_000_000
    else
      seconds = model[:provider] == :groq ? [ audio_seconds, 10 ].max : audio_seconds
      seconds / 60.0 * model[:audio_minute]
    end
    monthly_requests * (audio_cost + (300 * model[:text_input] + 30 * model[:output]) / 1_000_000)
  end

  def monthly_cost_krw(key)
    monthly_cost_usd(key) * usd_to_krw
  end
end
