require "application_system_test_case"

class CommunitySystemTest < ApplicationSystemTestCase
  test "switch modes write a post comment delete and switch language communities" do
    page.current_window.resize_to(390, 844)
    user = users(:one)
    visit authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth, expires_in: 5.minutes))
    within "nav[aria-label='Conversation mode']" do
      click_link "Community"
    end
    assert_current_path language_posts_path(languages(:english), tab: "learning")
    assert_no_button "Drop a voice"
    fill_in "Write a post", with: "Hello English community!"
    click_button "Post", exact: true
    assert_text "Hello English community!"
    fill_in "Write a comment", with: "My first comment"
    click_button "Comment", exact: true
    assert_text "My first comment"
    accept_confirm { find("button[aria-label='Delete comment']").click }
    assert_no_text "My first comment"
    assert_text "Comments (0)"
    within "#bottom-tab-bar" do
      assert_selector "a[aria-current='page']", count: 1, text: "Learning Language"
      click_link "Mother Language"
      assert_selector "a[aria-current='page']", count: 1, text: "Mother Language"
    end
    assert_current_path language_posts_path(languages(:korean), tab: "mother")
    assert_no_text "Hello English community!"
    within "nav[aria-label='Conversation mode']" do
      click_link "Voice"
    end
    assert_current_path rooms_path(tab: "mother")
    assert_button "Drop a voice"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    within "#bottom-tab-bar" do
      click_link "Learning Language"
    end
    assert_current_path rooms_path(tab: "learning")
    within "nav[aria-label='Conversation mode']" do
      click_link "Community"
    end
    accept_confirm { find("button[aria-label='Delete post']").click }
    assert_no_text "Hello English community!"
    assert_text "No posts yet."
  end
end
