require "application_system_test_case"

class VoiceFanoutSystemTest < ApplicationSystemTestCase
  test "retrying a recording after a lost response keeps one delivery and returns to its tab" do
    user = users(:english_speaker)
    visit authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth, expires_in: 5.minutes))
    within "#bottom-tab-bar" do
      click_link "Mother Language"
    end
    assert_current_path rooms_path(tab: "mother")
    page.execute_script <<~JS
      const element = document.querySelector('[data-controller~="voice-recorder"]');
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "voice-recorder");
      controller.sheetTarget.classList.remove("hidden");
      controller.startedAt = performance.now() - 1000;
      controller.recorder = { mimeType: "audio/webm" };
      controller.chunks = [new Blob(["voice-message"], { type: "audio/webm" })];
      controller.finishRecording();
      const originalFetch = window.fetch.bind(window);
      let loseResponse = true;
      window.fetch = async (...args) => {
        const response = await originalFetch(...args);
        if (loseResponse && String(args[0]).includes("voice_drop")) {
          loseResponse = false;
          await response.clone().json();
          throw new Error("Simulated lost response");
        }
        return response;
      };
    JS
    click_button "Send voice"
    assert_text "Simulated lost response"
    click_button "Try again"
    assert_text "Sent to 1 listener."
    assert_current_path rooms_path(tab: "mother")
    drop = VoiceDrop.find_by!(sender: user)
    assert_equal 1, VoiceDrop.where(sender: user).count
    assert_equal languages(:korean).id, drop.language_id
    assert_equal 1, drop.rooms.count
  end
end
