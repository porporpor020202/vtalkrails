require "application_system_test_case"
require "minitest/mock"
require "base64"
require "digest"
require_relative "../test_helpers/daily_practice_test_helper"

class CompletionShareTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  setup do
    @user = users(:korean_native)
    complete_practice(@user)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    sign_in(user: @user)
    @generator = Object.new
    @generator.define_singleton_method(:call) { |**| "What is your favorite color?" }
    @translator = Object.new
    @translator.define_singleton_method(:call) do |mode:, **|
      mode == "answer" ? { "english" => "I like green.", "ipa" => "/aɪ laɪk ɡrin/" } : { "translation" => "저는 초록색이 좋아요." }
    end
  end

  teardown do
    page.execute_script("delete window.webkit; delete window.PracticeShare; delete navigator.share; delete navigator.canShare")
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "mobile completion has an alpaca and a single large share button without scrolling" do
    assert_selector ".celebration-alpaca" do |img|
      img.evaluate_script("this.complete && this.naturalWidth > 0 && getComputedStyle(this).opacity === '1'")
    end
    assert_selector ".completion-count", text: /연속\s+1\s*일/
    assert_text "친구에게 공유하면 한 문장 더 연습해볼 수 있어요!"
    assert_selector ".celebration-actions .primary-button", count: 1
    assert_no_text "XP"
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    assert page.evaluate_script("document.querySelector('main').scrollHeight <= document.querySelector('main').clientHeight + 1")
    page.save_screenshot(Rails.root.join("tmp/completion-share-mobile.png"))
  end

  test "successful sharing opens a second sentence and its recording saves without another streak" do
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'canShare', { configurable: true, value: data => data.files[0].type === 'image/png' });
      Object.defineProperty(navigator, 'share', { configurable: true, value: async data => {
        window.sharedPractice = data;
        window.sharedCardPNG = await new Promise(resolve => {
          const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.readAsDataURL(data.files[0]);
        });
      } });
    JS
    with_bonus_services do
      click_button "친구에게 공유하기"
      assert_selector "dialog[open] .share-card-image" do |img|
        img.evaluate_script("this.complete && this.naturalWidth === 1080 && this.naturalHeight === 1350")
      end
      preview_png = card_png
      assert_equal 0, BonusPractice.count, "Preview alone must not unlock a bonus."
      click_button "카드 공유하기"
      assert_selector "#daily-question", text: "What is your favorite color?"
      assert_equal "image/png", page.evaluate_script("window.sharedPractice.files[0].type")
      assert_equal Digest::SHA256.hexdigest(preview_png), Digest::SHA256.hexdigest(page.evaluate_script("window.sharedCardPNG"))
      assert_includes page.evaluate_script("window.sharedPractice.text"), "https://sayonething.net"
      fill_in "input_text", with: "초록색이 좋아요."
      click_button "영어로 알아보기"
      assert_selector ".english-answer", text: "I like green."
      click_button "녹음 시작", enable_aria_label: true
      assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
      click_button "녹음 끝내기", enable_aria_label: true
      click_button "전송"
      assert_selector "h1", text: "잘했어요!"
      assert_text "두 문장이나 해냈어요. 정말 멋져요!"
      assert_selector ".completion-count", text: /연속\s+1\s*일/
      assert @user.bonus_practices.sole.audio.attached?
      assert_equal "I like green.", @user.bonus_practices.sole.english_sentence
      assert_selector ".completion-sentences p", count: 2
      assert_equal 1, @user.daily_practices.count
      assert_equal 1, @user.streak
      click_button "친구에게 공유하기"
      assert_selector "dialog[open] .share-card-image"
      page.save_screenshot(Rails.root.join("tmp/share-card-bonus-preview.png"))
      click_button "카드 공유하기"
      assert_no_selector "dialog[open]"
      assert_text "오늘은 두 문장 완료!"
      assert_equal 1, @user.bonus_practices.count
    end
  end

  test "cancelling the share sheet never grants a bonus" do
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'canShare', { configurable: true, value: () => true });
      Object.defineProperty(navigator, 'share', { configurable: true, value: async () => { throw new DOMException('Cancelled', 'AbortError') } });
    JS
    click_button "친구에게 공유하기"
    click_button "카드 공유하기"
    assert_selector "dialog[open]"
    assert_button "카드 공유하기", disabled: false
    assert_equal 0, BonusPractice.count
    assert_selector "h1", text: "잘했어요!"
    assert_no_selector ".share-status", text: /공유하지 못/
  end

  test "native share completion is used ahead of navigator share" do
    page.execute_script(<<~JS)
      window.webkit = { messageHandlers: { practiceShare: { postMessage: data => {
        window.nativeShareRequest = data;
        setTimeout(() => window.dispatchEvent(new CustomEvent('practice-share-result', { detail: { id: data.id, completed: true } })), 10);
      } } } };
      Object.defineProperty(navigator, 'share', { configurable: true, value: async () => { throw new Error('Native should handle the picker') } });
    JS
    with_bonus_services do
      click_button "친구에게 공유하기"
      preview_png = card_png
      click_button "카드 공유하기"
      assert_selector "#daily-question", text: "What is your favorite color?"
      assert_match /1일 연속/, page.evaluate_script("window.nativeShareRequest.text")
      assert_equal Digest::SHA256.hexdigest(preview_png), Digest::SHA256.hexdigest(page.evaluate_script("window.nativeShareRequest.imageDataUrl"))
    end
  end

  test "a browser without image sharing can download the card without earning a bonus" do
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', { configurable: true, value: undefined });
      Object.defineProperty(navigator, 'canShare', { configurable: true, value: undefined });
    JS
    click_button "친구에게 공유하기"
    assert_button I18n.t("ui.card_download", locale: :ko), disabled: false
    assert_text I18n.t("ui.card_save_hint", locale: :ko)
    page.execute_script(<<~JS)
      document.querySelector('[data-practice-share-target="download"]').addEventListener('click', event => {
        event.preventDefault(); window.downloadedCard = { href: event.currentTarget.href, name: event.currentTarget.download };
      });
    JS
    click_button I18n.t("ui.card_download", locale: :ko)
    assert_text "카드 다운로드를 시작했어요."
    assert_match /\Ablob:/, page.evaluate_script("window.downloadedCard.href")
    assert_equal "say-one-thing-ko.png", page.evaluate_script("window.downloadedCard.name")
    assert_equal 0, BonusPractice.count
  end

  test "English cards share the exact preview with English text while the app stays Korean" do
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'canShare', { configurable: true, value: () => true });
      Object.defineProperty(navigator, 'share', { configurable: true, value: async data => {
        window.sharedPractice = data;
        window.sharedCardPNG = await new Promise(resolve => {
          const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.readAsDataURL(data.files[0]);
        });
      } });
    JS
    with_bonus_services do
      click_button "친구에게 공유하기"
      native_png = card_png
      click_button "영어 버전 만들기"
      assert_selector '.share-card-image[lang="en"]'
      english_png = card_png
      assert_not_equal native_png, english_png
      assert_selector "html[lang=ko]"
      assert_button "한국어 버전 보기"
      assert_button "카드 공유하기", disabled: false
      assert_equal 0, BonusPractice.count
      click_button "카드 공유하기"
      assert_selector "#daily-question", text: "What is your favorite color?"
      assert_equal "I spoke English today! · Say One Thing", page.evaluate_script("window.sharedPractice.title")
      assert_includes page.evaluate_script("window.sharedPractice.text"), "1-day streak"
      assert_equal "say-one-thing-en.png", page.evaluate_script("window.sharedPractice.files[0].name")
      assert_equal english_png, page.evaluate_script("window.sharedCardPNG")
    end
  end

  test "English native sharing and returning to the original card use the selected PNG" do
    page.execute_script(<<~JS)
      window.PracticeShare = { postMessage: message => {
        const data = JSON.parse(message); window.nativeShareRequest = data;
        setTimeout(() => window.dispatchEvent(new CustomEvent('practice-share-result', { detail: { id: data.id, completed: false } })), 10);
      } };
    JS
    click_button "친구에게 공유하기"
    native_png = card_png
    click_button "영어 버전 만들기"
    assert_selector '.share-card-image[lang="en"]'
    english_png = card_png
    click_button "카드 공유하기"
    assert_button "한국어 버전 보기", disabled: false
    assert_equal english_png, page.evaluate_script("window.nativeShareRequest.imageDataUrl")
    assert_includes page.evaluate_script("window.nativeShareRequest.text"), "1-day streak"
    click_button "한국어 버전 보기"
    assert_selector '.share-card-image[lang="ko"]'
    assert_equal native_png, card_png
    assert_equal 0, BonusPractice.count
  end

  test "switching back during English generation cannot leave a stale preview or download" do
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', { configurable: true, value: undefined });
      Object.defineProperty(navigator, 'canShare', { configurable: true, value: undefined });
      const decode = Image.prototype.decode;
      Image.prototype.decode = function() {
        const ready = decode.call(this);
        return this.src.includes('app-store-en') ? ready.then(() => new Promise(resolve => { window.finishEnglishCard = resolve })) : ready;
      };
      document.querySelector('[data-practice-share-target="download"]').addEventListener('click', event => {
        event.preventDefault(); window.downloadedCard = { href: event.currentTarget.href, name: event.currentTarget.download };
      });
    JS
    click_button "친구에게 공유하기"
    native_png = card_png
    click_button "영어 버전 만들기"
    assert_selector '.share-card-language-button[aria-pressed="true"]' do
      page.evaluate_script("typeof window.finishEnglishCard === 'function'")
    end
    assert_button "이미지 저장하기", disabled: true
    assert_no_selector ".share-card-image"
    click_button "한국어 버전 보기"
    assert_selector '.share-card-image[lang="ko"]'
    page.evaluate_async_script("const done = arguments[0]; window.finishEnglishCard(); requestAnimationFrame(() => requestAnimationFrame(done))")
    assert_equal native_png, card_png
    click_button "이미지 저장하기"
    assert_equal "say-one-thing-ko.png", page.evaluate_script("window.downloadedCard.name")
    click_button "영어 버전 만들기"
    assert_selector '.share-card-image[lang="en"]'
    english_png = card_png
    click_button "이미지 저장하기"
    assert_equal "say-one-thing-en.png", page.evaluate_script("window.downloadedCard.name")
    assert_equal page.find(".share-card-image")["src"], page.evaluate_script("window.downloadedCard.href")
    assert_not_equal native_png, english_png
    assert_equal 0, BonusPractice.count
  end

  test "each language has a real PNG preview with the current streak and localized store badges" do
    %w[ko ja es zh zh-TW].each do |locale|
      @user.update!(native_language: locale)
      visit root_path
      assert_selector "html[lang='#{locale}']"
      click_button I18n.t("ui.share_button", locale: locale)
      assert_selector "dialog[open] .share-card-image" do |img|
        img.evaluate_script("this.complete && this.naturalWidth === 1080 && this.naturalHeight === 1350")
      end
      data = page.evaluate_script("JSON.parse(document.querySelector('[data-practice-share-card-value]').dataset.practiceShareCardValue)")
      assert_equal I18n.t("ui.card_headline", locale: locale), data["headline"]
      assert_equal [ "I had a good day." ], data["sentences"]
      assert_equal I18n.t("ui.practiced_sentence", locale: locale), data["sentenceLabel"]
      assert_selector ".completion-sentences p[lang=en]", text: "I had a good day."
      assert_selector ".next-practice-heading", text: I18n.t("ui.next", locale: locale)
      assert_selector ".next-practice-heading", text: I18n.t("ui.reset_time", locale: locale)
      assert_equal 1, data["streak"]
      assert_equal I18n.t("ui.card_streak_text", locale: locale, count: 1), data["streakText"]
      assert_match /app-store-#{Regexp.escape(locale)}[^\/]*\.svg/, data["appStoreBadgeUrl"]
      assert_match /google-play-#{Regexp.escape(locale)}[^\/]*\.png/, data["googlePlayBadgeUrl"]
      png = Base64.decode64(card_png.split(",", 2).last)
      assert_equal [ 1080, 1350 ], png.byteslice(16, 8).unpack("NN")
      assert_operator png.bytesize, :<, 2_000_000, "Native share bridges must accept the actual export."
      File.binwrite(Rails.root.join("tmp/share-card-#{locale}.png"), png)
      page.save_screenshot(Rails.root.join("tmp/share-card-preview-#{locale}.png"))
      assert page.evaluate_script("document.querySelector('dialog').scrollWidth <= document.querySelector('dialog').clientWidth")
      click_button I18n.t("ui.card_make_english", locale: locale)
      assert_selector '.share-card-image[lang="en"]'
      assert_selector "html[lang='#{locale}']"
      english = page.evaluate_script("JSON.parse(document.querySelector('[data-practice-share-english-card-value]').dataset.practiceShareEnglishCardValue)")
      assert_equal [ "I had a good day." ], english["sentences"]
      assert_equal "1-day streak", english["streakText"]
      assert_equal "Today's sentence", english["sentenceLabel"]
      assert_equal "Search for Say One Thing", english["searchHint"]
      assert_match /app-store-en[^\/]*\.svg/, english["appStoreBadgeUrl"]
      assert_match /google-play-en[^\/]*\.png/, english["googlePlayBadgeUrl"]
      assert_button I18n.t("ui.card_use_native", locale: locale)
      if locale == "ko"
        File.binwrite(Rails.root.join("tmp/share-card-en.png"), Base64.decode64(card_png.split(",", 2).last))
        page.save_screenshot(Rails.root.join("tmp/share-card-preview-en.png"))
      end
      click_button I18n.t("ui.card_close", locale: locale), enable_aria_label: true
      assert_no_selector "dialog[open]"
    end
    assert_equal 0, BonusPractice.count
  end

  test "long English sentences remain fully readable on completion and export a bounded card" do
    sentence = "I spent a lovely afternoon with my friends, sharing stories and enjoying coffee. " * 10
    @user.daily_practices.sole.update!(english_sentence: sentence.strip)
    visit root_path
    assert_selector ".completion-sentences p", text: sentence.strip
    assert page.evaluate_script("document.querySelector('main').scrollHeight > document.querySelector('main').clientHeight")
    click_button "친구에게 공유하기"
    png = Base64.decode64(card_png.split(",", 2).last)
    assert_equal [ 1080, 1350 ], png.byteslice(16, 8).unpack("NN")
    File.binwrite(Rails.root.join("tmp/share-card-long-sentence.png"), png)
    assert page.evaluate_script("document.querySelector('dialog').scrollWidth <= document.querySelector('dialog').clientWidth")
    click_button "닫기", enable_aria_label: true
    assert_no_selector "dialog[open]"
    assert_equal sentence.strip, @user.daily_practices.sole.english_sentence
  end

  test "small mobile preview keeps the image and share action inside the dialog" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 568, deviceScaleFactor: 1, mobile: true)
    page.execute_script("Object.defineProperty(navigator, 'canShare', { configurable: true, value: () => false })")
    click_button "친구에게 공유하기"
    assert_button I18n.t("ui.card_download", locale: :ko), disabled: false
    click_button "영어 버전 만들기"
    assert_selector '.share-card-image[lang="en"]'
    assert page.evaluate_script("document.querySelector('dialog').scrollHeight <= document.querySelector('dialog').clientHeight + 1")
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    page.save_screenshot(Rails.root.join("tmp/share-card-preview-small.png"))
    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector "dialog[open]"
    assert_equal 0, BonusPractice.count
  end

  private

  def card_png
    assert_selector ".share-card-image" do |img|
      img.evaluate_script("this.complete && this.naturalWidth === 1080")
    end
    page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      fetch(document.querySelector('.share-card-image').src).then(response => response.blob()).then(blob => {
        const reader = new FileReader(); reader.onload = () => done(reader.result); reader.readAsDataURL(blob);
      });
    JS
  end

  def with_bonus_services(&block)
    GeminiQuestion.stub(:new, -> { @generator }) do
      GeminiTranslation.stub(:new, -> { @translator }, &block)
    end
  end
end
