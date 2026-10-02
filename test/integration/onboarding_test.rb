require "test_helper"

class OnboardingTest < ActionDispatch::IntegrationTest
  setup do
    Current.reset
    Country.find_or_create_by!(code: "KR") { |country| country.name = "South Korea" }
    @user = User.create!(
      oauth_provider: "google",
      oauth_uid: "onboarding-#{SecureRandom.hex(8)}",
      email_address: "onboarding@example.com"
    )
  end

  teardown { Current.reset }

  test "비로그인 사용자는 온보딩 화면과 저장에 접근할 수 없다" do
    get onboarding_path
    assert_redirected_to new_session_path

    patch onboarding_path, params: { user: { display_name: "Tester", country_code: "KR" } }
    assert_redirected_to new_session_path
    assert_nil @user.reload.display_name
    assert_nil @user.country_code
  end

  test "닉네임과 국가를 저장하면 온보딩을 완료하고 홈으로 이동한다" do
    sign_in_as @user

    get onboarding_path
    assert_response :success
    assert_select "select[name='user[country_code]'] option[value='KR']", "South Korea"

    patch onboarding_path, params: { user: { display_name: "  Tester  ", country_code: "KR" } }

    assert_redirected_to root_url
    assert_equal "Tester", @user.reload.display_name
    assert_equal "KR", @user.country_code
    assert @user.onboarding_complete?
    assert Rails.root.join("app/assets/images", @user.profile_image_path_for).file?
  end

  [
    { label: "닉네임 누락", display_name: "   ", country_code: "KR" },
    { label: "국가 누락", display_name: "Tester", country_code: "" },
    { label: "등록되지 않은 국가", display_name: "Tester", country_code: "ZZ" },
    { label: "중복 닉네임", display_name: "Calm Tiger", country_code: "KR" }
  ].each do |scenario|
    test "#{scenario[:label]}이면 저장하지 않고 오류를 표시한다" do
      sign_in_as @user

      patch onboarding_path, params: { user: scenario.slice(:display_name, :country_code) }

      assert_response :unprocessable_entity
      assert_select "[role='alert']"
      assert_nil @user.reload.display_name
      assert_nil @user.country_code
    end
  end

  test "r_이미 온보딩을 완료한 사용자는 홈으로 이동한다" do
    sign_in_as users(:korean_native)
    assert Current.user.onboarding_complete?

    get onboarding_path

    assert_redirected_to root_url
  end
end
