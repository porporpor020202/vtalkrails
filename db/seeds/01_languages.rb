[
  { name: "English", code: "en" },
  { name: "Korean", code: "ko" }
].each do |attributes|
  language = Language.find_or_initialize_by(code: attributes[:code])
  language.update!(name: attributes[:name])
end
