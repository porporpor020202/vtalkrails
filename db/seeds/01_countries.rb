require "json"

# Country/region codes: Google's libaddressinput (excluding ZZ / Unknown Region).
# https://github.com/google/libaddressinput/blob/master/common/src/main/java/com/google/i18n/addressinput/common/RegionDataConstants.java
# English names: Unicode CLDR.
# https://github.com/unicode-org/cldr-json/blob/main/cldr-json/cldr-localenames-full/main/en/territories.json
# Snapshot retrieved on 2026-10-02. Kept locally so seeding requires no network.
countries = JSON.parse(Rails.root.join("db/seeds/data/countries.json").read)

Country.transaction do
  countries.each do |code, name|
    country = Country.find_or_initialize_by(code: code)
    country.name = name
    country.save! if country.new_record? || country.changed?
  end
end
