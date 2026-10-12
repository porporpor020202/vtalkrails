languages = {
  "en" => "English",
  "ja" => "Japanese",
  "ko" => "Korean",
  "zh" => "Chinese",
  "es" => "Spanish"
}

Language.transaction do
  Language.where.not(code: languages.keys).update_all(enable: false)

  languages.each do |code, label|
    Language.find_or_initialize_by(code: code).tap do |language|
      language.label = label
      language.enable = true
      language.save!
    end
  end
end
