module PagesHelper
  def landing_google_play_url
    "https://play.google.com/store/apps/details?id=com.porporpor020202.vtalkandroid"
  end

  def landing_app_store_url
    "https://apps.apple.com/app/say-one-thing/id6792954921"
  end

  def landing_install_url
    agent = request.user_agent.to_s

    return landing_google_play_url if agent.match?(/Android/i)
    return landing_app_store_url if agent.match?(/iPhone|iPad|iPod/i)

    landing_google_play_url
  end
end
