require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "profile icons render as images for old and new accounts" do
    [ "🦝", "emoji/animals_and_nature/raccoon_3d.png" ].each do |icon|
      html = profile_icon_tag(User.new(icon: icon), size: 32)
      assert_match(/<img[^>]+raccoon_3d/, html)
      assert_includes html, 'width="32"'
      assert_includes html, 'height="32"'
      refute_includes html, "🦝"
    end
  end
end
