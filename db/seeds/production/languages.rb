# Native-language options based on Duolingo's language courses.
# Omit fictional languages, Latin, and Esperanto; retain existing native languages.
languages = {
  "ar" => "Arabic",
  "bn" => "Bengali",
  "zh" => "Chinese",
  "cs" => "Czech",
  "da" => "Danish",
  "nl" => "Dutch",
  "en" => "English",
  "fi" => "Finnish",
  "fr" => "French",
  "de" => "German",
  "el" => "Greek",
  "gu" => "Gujarati",
  "ht" => "Haitian Creole",
  "ha" => "Hausa",
  "haw" => "Hawaiian",
  "he" => "Hebrew",
  "hi" => "Hindi",
  "hu" => "Hungarian",
  "id" => "Indonesian",
  "ga" => "Irish",
  "it" => "Italian",
  "ja" => "Japanese",
  "ko" => "Korean",
  "mr" => "Marathi",
  "nv" => "Navajo",
  "nb" => "Norwegian (Bokmål)",
  "fa" => "Persian",
  "pl" => "Polish",
  "pt" => "Portuguese",
  "pa" => "Punjabi",
  "ro" => "Romanian",
  "ru" => "Russian",
  "gd" => "Scottish Gaelic",
  "es" => "Spanish",
  "sw" => "Swahili",
  "sv" => "Swedish",
  "ta" => "Tamil",
  "te" => "Telugu",
  "tr" => "Turkish",
  "uk" => "Ukrainian",
  "vi" => "Vietnamese",
  "cy" => "Welsh",
  "yi" => "Yiddish",
  "zu" => "Zulu"
}

languages.each do |code, label|
  Language.find_or_initialize_by(code: code).tap do |language|
    language.label = label
    language.enable = true
    language.save!
  end
end
