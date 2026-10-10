require "application_system_test_case"
require "minitest/mock"

class VoiceHelperFlowTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  setup do
    sign_in(user: users(:korean_native))
    visit rooms_path
    click_button "Drop a voice"
    click_button "How do I say this in English?"
    # 헤드리스 브라우저에서 너무 빨리 멈추면 0바이트가 될 수 있다.
    # 실제 첫 오디오 청크 이벤트를 관찰해 준비 여부만 DOM에 표시한다.
    page.execute_script(<<~JS)
      const NativeMediaRecorder = window.MediaRecorder;
      window.MediaRecorder = class extends NativeMediaRecorder {
        constructor(...args) {
          super(...args);
          this.addEventListener("dataavailable", event => {
            if (event.data.size > 0) document.querySelector('[data-phrase-demo-target="microphone"]').dataset.audioReady = "true";
          });
        }
      };
    JS
  end

  test "사용 방법은 별도 모달로 열리고 닫히며 How to use는 오른쪽에 표시된다" do
    # 설명을 접었을 때 긴 안내가 녹음 시트를 밀어내지 않아야 한다.
    assert_no_selector 'dialog[data-phrase-demo-target="instructions"]'
    assert_right_aligned("How to use")
    click_button "How to use"
    within 'dialog[data-phrase-demo-target="instructions"]:modal' do
      assert_text "Speak in your native language."
      assert_text "A question"
      assert_text "A sentence"
      assert_text "Just a word"
      assert_text "Get just the English words you need."
      click_button "Close instructions", enable_aria_label: true
    end
    assert_no_selector 'dialog[data-phrase-demo-target="instructions"]'
    assert_button "Start voice helper", enable_aria_label: true
  end

  test "마이크로 녹음한 뒤 영어만 표시하고 Try another로 다시 시작할 수 있다" do
    # 브라우저의 실제 MediaRecorder와 서버 HTTP 경로를 사용한다.
    # 공급자만 대체하므로 마이크 클릭/업로드/결과 전환을 함께 검증한다.
    helper = Object.new
    uploads = []
    helper.define_singleton_method(:call) do |audio:|
      uploads << audio.size
      "I don't want to go to a wedding."
    end
    VoiceHelper.stub(:new, ->(*) { helper }) do
      record_translation
      within '[data-phrase-demo-target="result"]' do
        assert_selector '[data-phrase-demo-target="english"]', exact_text: "I don't want to go to a wedding."
        assert_button "Read English aloud", enable_aria_label: true
        assert_right_aligned("Try another")
        click_button "Try another"
      end
      assert_no_selector '[data-phrase-demo-target="result"]'
      assert_button "Start voice helper", enable_aria_label: true
      assert uploads.first.positive?, "A real recorded blob must reach the server"
    end
  end

  test "Listen으로 API 음성을 재생하고 멈추며 같은 음성을 다시 재생할 때 재생성하지 않는다" do
    # HTML audio의 실제 재생 상태를 확인한다. 음질은 무음 테스트 파일로 판단하지 않는다.
    helper = Object.new
    helper.define_singleton_method(:call) { |audio:| "Wedding" }
    calls = []
    speech = Object.new
    speech.define_singleton_method(:content_type) { "audio/wav" }
    wav = wav_audio
    speech.define_singleton_method(:call) { |text| calls << text; wav }
    VoiceHelper.stub(:new, ->(*) { helper }) do
      TextToSpeech.stub(:new, -> { speech }) do
        record_translation
        click_button "Read English aloud", enable_aria_label: true
        assert_selector '[data-phrase-demo-target="playback"][src^="blob:"]'
        assert_button "Stop reading aloud", enable_aria_label: true
        click_button "Stop reading aloud", enable_aria_label: true
        assert_button "Read English aloud", enable_aria_label: true
        click_button "Read English aloud", enable_aria_label: true
        assert_button "Stop reading aloud", enable_aria_label: true
        assert_equal [ "Wedding" ], calls
        click_button "Try another"
        assert_no_selector '[data-phrase-demo-target="playback"][src]', visible: :all
      end
    end
  end

  test "번역 API가 실패하면 오류 안내를 표시하고 다시 녹음할 수 있다" do
    # 오류에서 멈춰 버튼이 비활성화되는 문제와 빈 결과 노출을 방지한다.
    helper = Object.new
    helper.define_singleton_method(:call) { |audio:| raise VoiceHelper::Unavailable, "Voice helper is temporarily unavailable. Please try again." }
    VoiceHelper.stub(:new, ->(*) { helper }) do
      click_button "Start voice helper", enable_aria_label: true
      assert_text "Listening… Tap again to translate."
      assert_selector '[data-phrase-demo-target="microphone"][data-audio-ready="true"]'
      click_button "Stop and translate", enable_aria_label: true
      assert_selector '[data-phrase-demo-target="status"][role="alert"]', text: "Voice helper is temporarily unavailable."
      assert_button "Start voice helper", enable_aria_label: true, disabled: false
      assert_no_selector '[data-phrase-demo-target="result"]'
    end
  end

  private

  def record_translation
    click_button "Start voice helper", enable_aria_label: true
    assert_text "Listening… Tap again to translate."
    assert_selector '[data-phrase-demo-target="microphone"][data-audio-ready="true"]'
    # 녹음 시작 상태를 기다린 뒤 멈춘다. 중지 시 마지막 청크가 업로드된다.
    assert_button "Stop and translate", enable_aria_label: true
    click_button "Stop and translate", enable_aria_label: true
    assert_selector '[data-phrase-demo-target="result"]'
  end

  def assert_right_aligned(text)
    # 클래스명이 아닌 화면 좌표를 비교해 실제 오른쪽 배치를 확인한다.
    button = find_button(text)
    assert page.evaluate_script(<<~JS, button)
      arguments[0].getBoundingClientRect().right >
        arguments[0].parentElement.getBoundingClientRect().left + arguments[0].parentElement.getBoundingClientRect().width * 0.8
    JS
  end

  def wav_audio
    # 8초 무음 WAV로 외부 TTS를 호출하지 않고 브라우저 재생 상태를 확인한다.
    samples = "\0".b * (8000 * 8 * 2)
    "RIFF" + [ 36 + samples.bytesize ].pack("V") + "WAVEfmt " +
      [ 16, 1, 1, 8000, 16000, 2, 16 ].pack("VvvVVvv") + "data" + [ samples.bytesize ].pack("V") + samples
  end
end
