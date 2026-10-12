require "test_helper"

class OnboardingChoicesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:english_native)
    @user.update!(age_confirmed_at: nil, onboarding_completed_at: nil)
    sign_in_as(@user)
    @choices = { native_language_id: languages(:english).id, age_group: "18_24", gender: "female", microphone_confirmed: "1", community_rules_accepted: "1" }
  end

  test "adult choices and explicit consent are persisted" do
    patch onboarding_path, params: { user: @choices }
    assert_redirected_to root_path
    assert_equal "18_24", @user.reload.age_group
    assert_equal "female", @user.gender
    assert @user.onboarding_complete?
  end

  test "underage invalid or missing choices cannot bypass onboarding" do
    [{ age_group: "under_18" }, { age_group: "unknown" }, { age_group: "" }, { gender: "" }, { gender: "invalid" }, { microphone_confirmed: "0" }, { community_rules_accepted: "0" }].each do |invalid|
      patch onboarding_path, params: { user: @choices.merge(invalid) }
      assert_response :unprocessable_entity
      assert_not @user.reload.onboarding_complete?
      assert_nil @user.age_confirmed_at
    end
  end
end
