require "test_helper"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class MarketingTrackingTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup do
    question_for
    patch native_language_path, params: { native_language: "ko" }
  end

  test "a campaign follows the guest through translations recording signup and exact saved audio" do
    get root_path, params: { utm_source: "youtube", utm_medium: "social", utm_campaign: "first-short", utm_content: "description", access_token: "never-store-this" }, headers: { "Referer" => "https://www.youtube.com/shorts/private-path?secret=never-store-this" }
    visit = MarketingVisit.sole
    assert_equal [ "youtube", "social", "first-short", "description", "www.youtube.com", "/" ], visit.attributes.values_at("source", "medium", "campaign", "content", "referrer_host", "landing_path")
    assert_not_includes visit.to_json, "never-store-this"
    2.times { get root_path }
    assert_equal 1, MarketingVisit.count
    assert_equal 1, MarketingEvent.where(name: "app_open").count
    assert_equal 1, MarketingEvent.where(name: "question_viewed").count

    translator = Object.new
    translator.define_singleton_method(:call) do |mode:, **|
      mode == "answer" ? { "english" => "I had a good day.", "ipa" => "/aɪ hæd ə ɡʊd deɪ/" } : { "translation" => "좋은 하루였어요." }
    end
    GeminiTranslation.stub(:new, -> { translator }) do
      %w[example question answer].each do |mode|
        2.times { post language_help_path, params: { mode: mode, question_token: question_for.signed_id(purpose: :daily_question), input_text: "좋은 하루였어요." }; assert_response :success }
        assert_equal 0, MarketingEvent.where(name: %w[question_translation_used answer_translation_used]).count if mode == "example"
      end
    end
    assert_equal 1, MarketingEvent.where(name: "answer_translation_used").count
    assert_equal 1, MarketingEvent.where(name: "question_translation_used").count
    assert_not_includes MarketingEvent.all.to_json, "좋은 하루였어요"
    %w[recording_started recording_completed].each do |name|
      2.times { post marketing_events_path, params: { name: name, question_token: question_for.signed_id(purpose: :daily_question) }, as: :json; assert_response :no_content }
    end
    2.times do
      post daily_practice_path, params: { question_token: question_for.signed_id(purpose: :daily_question), daily_practice: { audio: audio_upload, duration_ms: 2000 } }
      assert_response :created
    end
    practice = DailyPractice.sole
    blob_id = practice.audio.blob.id
    assert_equal 1, MarketingEvent.where(name: "practice_completed").count
    user = User.create!(email_address: "campaign@example.com", oauth_provider: "google", oauth_uid: "marketing-new-user")
    get authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth))
    assert_redirected_to root_url
    follow_redirect!
    assert_select ".practice-saved"
    assert_equal user.id, practice.reload.user_id
    assert_equal blob_id, practice.audio.blob.id
    assert_equal user.id, visit.reload.user_id
    assert_equal visit.id, MarketingEvent.find_by!(name: "signup", user: user).marketing_visit_id
    assert MarketingEvent.where(name: "practice_completed", user: user, authenticated: false).exists?
    assert MarketingEvent.where(name: "guest_recording_claimed", user: user, authenticated: true).exists?
    report = MarketingReport.new(from: Date.current, through: Date.current)
    %i[visitors new_accounts answer_translation question_translation recording_started recording_completed practice_completed guest_recorders recorded_then_signup saved_after_login].each { |key| assert_equal 1, report.summary[key], key.to_s }
    assert_equal "first-short", report.sources.sole[:campaign]

    delete account_path
    assert_not User.exists?(user.id)
    assert_not MarketingEvent.where(user_id: user.id).exists?
    assert_not MarketingVisit.exists?(visit.id)
  end

  test "campaigns and expired visits do not inflate device counts and referrers retain no URLs" do
    get root_path, params: { utm_source: "threads", utm_campaign: "post-a" }
    2.times { get root_path, params: { utm_source: "threads", utm_campaign: "post-a" } }
    assert_equal 1, MarketingVisit.count
    get root_path, params: { utm_source: "threads", utm_campaign: "post-b" }
    assert_equal 2, MarketingVisit.count
    assert_equal 1, MarketingVisit.distinct.count(:visitor_key)
    travel 31.minutes
    get root_path, headers: { "Referer" => "https://blog.example.com/path-with-private-information?password=secret" }
    assert_equal "blog.example.com", MarketingVisit.order(:id).last.source
    assert_equal "referral", MarketingVisit.order(:id).last.medium
    assert_not_includes MarketingVisit.all.to_json, "password"
    assert_equal 1, MarketingReport.new(from: Date.current, through: Date.current).summary[:visitors]
    cookies.delete("marketing_visitor_id")
    get root_path, headers: { "Referer" => "invalid%bad" }
    assert_equal "direct", MarketingVisit.order(:id).last.source
  end

  test "client events cannot forge signups saved recordings users or stale questions" do
    %w[signup practice_completed answer_translation_used unknown].each do |name|
      assert_no_difference "MarketingEvent.count" do
        post marketing_events_path, params: { name: name, user_id: users(:korean_native).id }, as: :json
        assert_response :unprocessable_entity
      end
    end
    post marketing_events_path, params: { name: "recording_completed", question_token: "invalid" }, as: :json
    assert_response :unprocessable_entity
    post marketing_events_path, params: { name: "app_open", user_id: users(:korean_native).id, occurred_at: "2000-01-01", input_text: "do-not-store" }, as: :json
    assert_response :no_content
    assert_nil MarketingEvent.sole.user_id
    assert_equal Date.current, MarketingEvent.sole.occurred_at.to_date
    assert_not_includes MarketingEvent.sole.to_json, "do-not-store"
  end

  test "bot previews prefetches health and admin browsing do not count as marketing visits" do
    assert_no_difference "MarketingVisit.count" do
      get root_path, headers: { "User-Agent" => "Googlebot" }
      get root_path, headers: { "User-Agent" => "kakaotalk-scrap/1.0" }
      get root_path, headers: { "User-Agent" => "WhatsApp/2.26" }
      get root_path, headers: { "Sec-Purpose" => "prefetch" }
      get rails_health_check_path
      get privacy_path
    end
    get root_path
    admin = users(:english_native)
    admin.update!(email_address: "porporpor020202@gmail.com")
    get authenticate_by_token_google_oauth_sessions_path(token: admin.signed_id(purpose: :native_auth))
    follow_redirect!
    get admin_marketing_path
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal 0, MarketingVisit.external.count
    assert_equal 0, MarketingReport.new(from: Date.current, through: Date.current).summary[:visitors]
  end

  test "analytics failures do not stop practice and a foreground visit does not spend an AI day" do
    MarketingVisit.stub(:find_by, ->(**) { raise ActiveRecord::StatementInvalid, "temporary analytics failure" }) do
      get root_path
      assert_response :success
      assert_select "#daily-question"
      prepare_recording_translation
      post daily_practice_path, params: { question_token: question_for.signed_id(purpose: :daily_question), daily_practice: { audio: audio_upload, duration_ms: 2000 } }
      assert_response :created
      assert DailyPractice.sole.audio.attached?
    end
    user = users(:korean_native)
    get authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth))
    before = AiUsage.order(:id).pluck(:id, :training_dates, :help_data)
    travel_to Date.tomorrow.in_time_zone + 1.minute do
      post marketing_events_path, params: { name: "app_open" }, as: :json
      assert_response :no_content
      assert_equal before, AiUsage.order(:id).pluck(:id, :training_dates, :help_data)
      assert MarketingEvent.where(name: "app_open", user: user, occurred_at: Date.current.all_day).exists?
    end
  end

  test "logging out and switching accounts never assigns the former users events to a new account" do
    first = users(:korean_native)
    second = users(:spanish_native)
    get authenticate_by_token_google_oauth_sessions_path(token: first.signed_id(purpose: :native_auth))
    get root_path
    first_visit = MarketingVisit.order(:id).last
    delete session_path
    get root_path
    guest_visit = MarketingVisit.order(:id).last
    assert_not_equal first_visit.id, guest_visit.id
    assert_nil guest_visit.user_id
    get authenticate_by_token_google_oauth_sessions_path(token: second.signed_id(purpose: :native_auth))
    assert_equal first.id, first_visit.reload.user_id
    assert_equal second.id, guest_visit.reload.user_id
    assert MarketingEvent.where(marketing_visit: first_visit, user: first).exists?
    assert_not MarketingEvent.where(marketing_visit: first_visit, user: second).exists?
  end

  test "Apple cross site callback preserves campaign as well as guest recording" do
    https!
    get root_path, params: { utm_source: "instagram", utm_campaign: "apple-post" }
    prepare_recording_translation
    post daily_practice_path, params: { question_token: question_for.signed_id(purpose: :daily_question), daily_practice: { audio: audio_upload, duration_ms: 2000 } }
    user = User.create!(email_address: "apple-campaign@example.com", oauth_provider: "apple", oauth_uid: "marketing-apple")
    captured = {}
    client = Object.new
    client.define_singleton_method(:authorization_url) { |**args| captured.merge!(args); "https://appleid.apple.com/auth/authorize" }
    client.define_singleton_method(:authenticate) { |**| { uid: user.oauth_uid, email: user.email_address } }
    AppleOauthClient.stub(:new, -> { client }) do
      post apple_oauth_sessions_path, params: { platform: "web" }
      cookies.delete(Rails.application.config.session_options[:key])
      post callback_apple_oauth_sessions_path, params: { state: captured[:state], code: "verified-code" }, headers: { "Origin" => "https://appleid.apple.com", "Referer" => "https://appleid.apple.com/" }
      assert_redirected_to root_url
    end
    assert_equal "apple-post", MarketingEvent.find_by!(name: "signup", user: user).marketing_visit.campaign
    assert_equal 1, MarketingReport.new(from: Date.current, through: Date.current).summary[:recorded_then_signup]
  end
end
