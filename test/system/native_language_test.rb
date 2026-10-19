require "application_system_test_case"
require_relative "../test_helpers/daily_practice_test_helper"

class NativeLanguageFlowTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper

  test "mobile visitor selects a language and can change it without signing in" do
    question_for
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit root_path
    assert_button "계속하기", disabled: true
    page.save_screenshot(Rails.root.join("tmp/native-language-selection.png"))
    choose "日本語", allow_label_click: true
    assert_selector "h1", text: "どの言語を話しますか？"
    assert_button "続ける", disabled: false
    click_button "続ける"
    assert_selector "html[lang=ja]"
    assert_text "言いたいことを日本語で書いてください。まず英語の表現を確認して、声に出してみましょう！"
    assert_no_button "録音を開始", enable_aria_label: true
    assert_text I18n.t("ui.translate_before_recording", locale: :ja)
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    click_link "設定", enable_aria_label: true
    click_link "母語: 日本語"
    choose "Español", allow_label_click: true
    click_button "Continuar"
    assert_selector "html[lang=es]"
    assert_text "Escribe lo que quieres decir en español. ¡Primero comprueba cómo se dice en inglés y dilo en voz alta!"
    visit root_path
    assert_no_selector ".language-page"
    assert_selector "html[lang=es]"
    page.save_screenshot(Rails.root.join("tmp/native-language-spanish.png"))
    translate_in_browser
    page.execute_script("navigator.mediaDevices.getUserMedia = async () => { throw new DOMException('Denied', 'NotAllowedError') }")
    click_button "Grabar", enable_aria_label: true
    assert_text "Permite el micrófono en los ajustes del navegador o dispositivo y vuelve a intentarlo."
    assert_button "Grabar", enable_aria_label: true
  end
  test "traditional Chinese selection localizes the page and microphone controls" do
    question_for
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit root_path
    assert_equal %w[es ja ko zh zh-TW], all('input[type="radio"]', visible: :all).map(&:value)
    choose "繁體中文", allow_label_click: true
    assert_selector "h1", text: "你使用什麼語言？"
    click_button "繼續"
    assert_selector "html[lang=zh-TW]"
    assert_no_button "開始錄音", enable_aria_label: true
    assert_text I18n.t("ui.translate_before_recording", locale: :"zh-TW")
    assert_text "用繁體中文寫下你想說的話。先看看英語怎麼說，再大膽說出來！"
    translate_in_browser
    page.execute_script("navigator.mediaDevices.getUserMedia = async () => { throw new DOMException('Denied', 'NotAllowedError') }")
    click_button "開始錄音", enable_aria_label: true
    assert_text "請在瀏覽器或裝置設定中允許麥克風權限後重試。"
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
    page.save_screenshot(Rails.root.join("tmp/native-language-traditional.png"))
  end

end
