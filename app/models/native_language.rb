# The supported UI languages and the names used in translation prompts.
class NativeLanguage
  # Follow Duolingo’s site-language list; keep both Chinese writing systems together.
  OPTIONS = {
    "es" => { name: "Español", english: "Spanish", badge: "Ñ" },
    "ja" => { name: "日本語", english: "Japanese", badge: "あ" },
    "ko" => { name: "한국어", english: "Korean", badge: "한" },
    "zh" => { name: "简体中文", english: "Simplified Chinese", badge: "简" },
    "zh-TW" => { name: "繁體中文", english: "Traditional Chinese", badge: "繁" }
  }.freeze

  def self.supported?(value)
    OPTIONS.key?(value.to_s)
  end
end
