[
  { name: "English", code: "en", enabled: true },
  { name: "Korean", code: "ko", enabled: true },
  { name: "French", code: "fr", enabled: false },
  { name: "Spanish", code: "es", enabled: false }
].each do |attributes|
  Language.find_or_create_by!(attributes)
end
