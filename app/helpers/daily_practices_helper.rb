module DailyPracticesHelper
  def completed_practice_sentences
    [ @practice&.english_sentence, (@bonus.english_sentence if @bonus&.completed?) ].compact_blank
  end

  def practice_share_card_data(locale: I18n.locale)
    scope = locale.to_s == "en" ? "share_card" : "ui"
    {
      locale: locale,
      headline: t("#{scope}.card_headline", locale: locale),
      streak: @streak,
      streakText: t("#{scope}.card_streak_text", locale: locale, count: @streak),
      searchHint: t("#{scope}.card_search_hint", locale: locale),
      sentenceLabel: t("#{scope}.practiced_sentence", locale: locale),
      shareText: t("#{scope}.share_text", locale: locale, count: @streak),
      sentences: completed_practice_sentences,
      mascotUrl: asset_path("alpaca-celebrate.png"),
      appStoreBadgeUrl: asset_path("store-badges/app-store-#{locale}.svg"),
      googlePlayBadgeUrl: asset_path("store-badges/google-play-#{locale}.png")
    }
  end
end
