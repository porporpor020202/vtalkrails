module DailyPracticesHelper
  def completed_practice_sentences
    [ @practice&.english_sentence, (@bonus.english_sentence if @bonus&.completed?) ].compact_blank
  end

  def practice_share_card_data
    {
      locale: I18n.locale,
      headline: t("ui.card_headline"),
      streak: @streak,
      streakText: t("ui.card_streak_text", count: @streak),
      searchHint: t("ui.card_search_hint"),
      sentenceLabel: t("ui.practiced_sentence"),
      sentences: completed_practice_sentences,
      mascotUrl: asset_path("alpaca-celebrate.png"),
      appStoreBadgeUrl: asset_path("store-badges/app-store-#{I18n.locale}.svg"),
      googlePlayBadgeUrl: asset_path("store-badges/google-play-#{I18n.locale}.png")
    }
  end
end
