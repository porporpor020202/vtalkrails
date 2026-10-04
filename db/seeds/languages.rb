languages = {
  "ar" => "Arabic", "bn" => "Bengali", "zh" => "Chinese",
  "nl" => "Dutch", "en" => "English", "fr" => "French",
  "de" => "German", "gu" => "Gujarati", "ha" => "Hausa",
  "hi" => "Hindi", "id" => "Indonesian", "it" => "Italian",
  "ja" => "Japanese", "ko" => "Korean", "mr" => "Marathi",
  "fa" => "Persian", "pl" => "Polish", "pt" => "Portuguese",
  "pa" => "Punjabi", "ru" => "Russian", "es" => "Spanish",
  "ta" => "Tamil", "te" => "Telugu", "tr" => "Turkish",
  "vi" => "Vietnamese"
}

languages.each do |code, label|
  Language.find_or_initialize_by(code: code).tap do |language|
    language.label = label
    language.enable = %w[en ko].include?(code)
    language.save!
  end
end
