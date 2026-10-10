class TextToSpeechSetting < ApplicationRecord
  # Each model has its own key, independent of the translation keys.
  MODELS = {
    "gemini_lite" => { name: "Gemini 3.8 Flash-Lite TTS", provider: :gemini, model: "gemini-3.8-flash-lite-tts", voice: "Kore", audio_output: 6, description: "Preview. Low-latency Gemini voice; uses an AI Studio API key." },
    "gemini_flash" => { name: "Gemini 3.8 Flash TTS", provider: :gemini, model: "gemini-3.8-flash-tts", voice: "Kore", audio_output: 9, description: "Preview. Expressive Gemini voice; uses an AI Studio API key." },
    "wavenet" => { name: "Google WaveNet", provider: :google, voice: "en-US-Wavenet-F", price: 4, description: "Low-cost English voice." },
    "neural2" => { name: "Google Neural2", provider: :google, voice: "en-US-Neural2-F", price: 16, description: "Neural English voice." },
    "chirp3" => { name: "Google Chirp 3 HD", provider: :google, voice: "en-US-Chirp3-HD-Aoede", price: 30, description: "Conversational English voice. Initial selection." },
    "tts1" => { name: "OpenAI TTS-1", provider: :openai, model: "tts-1", voice: "nova", price: 15, description: "Legacy model; scheduled removal January 6, 2027." },
    "tts1hd" => { name: "OpenAI TTS-1 HD", provider: :openai, model: "tts-1-hd", voice: "nova", price: 30, description: "Higher-quality legacy model; scheduled removal January 6, 2027." }
  }.freeze
  API_KEY_FIELDS = MODELS.keys.map { |key| "#{key}_api_key" }.freeze

  encrypts(*API_KEY_FIELDS, key_provider: ActiveRecord::Encryption::KeyProvider.new(
    ActiveRecord::Encryption::Key.new(Rails.application.key_generator.generate_key("text-to-speech-api-keys", 32))
  ))

  validates :model_key, inclusion: { in: MODELS.keys }
  validates :estimated_users, :daily_uses, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1_000_000 }
  validates :text_characters, numericality: { only_integer: true, in: 1..1000 }
  validates :audio_seconds, numericality: { only_integer: true, in: 1..120 }
  validates :usd_to_krw, numericality: { greater_than: 0, less_than_or_equal_to: 100_000 }

  def self.current
    find_by(id: 1) || create_or_find_by!(id: 1)
  end

  def api_key(key = model_key)
    public_send("#{key}_api_key").presence
  end

  def monthly_requests
    estimated_users * daily_uses * 30
  end

  def monthly_cost_usd(key)
    model = MODELS.fetch(key)
    if model[:provider] == :gemini
      # Estimate English text at four characters/token plus 30 style/metadata tokens.
      # Gemini bills output audio at 25 tokens/second. Published preview rates double in 2027.
      multiplier = Date.current >= Date.new(2027, 1, 1) ? 2 : 1
      monthly_requests * ((text_characters / 4.0 + 30) * 0.5 + audio_seconds * 25 * model[:audio_output]) * multiplier / 1_000_000.0
    else
      monthly_requests * text_characters * model[:price] / 1_000_000.0
    end
  end

  def monthly_cost_krw(key)
    monthly_cost_usd(key) * usd_to_krw
  end
end
