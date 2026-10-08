require "test_helper"
require_relative "test_helpers/system_session_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemSessionTestHelper

  # Capybara는 드라이버 이름을 기준으로 브라우저를 재사용한다.
  # 마이크 권한을 자동 허용하는 테스트와 직접 권한을 설정하는 테스트가
  # 서로의 Chrome 설정을 물려받지 않도록 설정별로 이름을 분리한다.
  def self.driven_by(driver, **options, &block)
    if driver == :selenium
      options[:options] = { name: "#{driver}_#{name}".to_sym }.merge(options.fetch(:options, {}))
    end
    super(driver, **options, &block)
  end

  # driven_by :selenium, using: :chrome, screen_size: [1400, 1000]
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
    options.add_preference "intl.accept_languages", "en-US,en"
  end
end
