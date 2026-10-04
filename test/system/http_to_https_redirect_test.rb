require "remote_origin_test_case"

class HttpToHttpsRedirectTest < RemoteOriginTestCase
  ORIGINS::HTTP_ORIGINS.each do |origin|
    test "r_#{origin}의 HTTP 요청이 HTTPS로 자동 리다이렉트된다" do
      https_origin = origin.sub(/\Ahttp:/, "https:")

      visit "#{origin}/session/new"

      assert_current_path "#{https_origin}/session/new", url: true, wait: 4
      assert_selector "h1", exact_text: "Say One Thing", wait: 4
    end
  end
end
