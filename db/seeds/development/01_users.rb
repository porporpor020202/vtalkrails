[
  {
    email_address: "porporpor020202@gmail.com",
    oauth_uid: "105585320555912094353",
    display_name: "Brilliant Hot Pepper"
  },
  {
    email_address: "por00225744@gmail.com",
    oauth_uid: "111399595835417597285",
    display_name: "Soft Green Apple"
  }
].each do |attributes|
  User.find_or_create_by!(
    oauth_provider: :google,
    oauth_uid: attributes[:oauth_uid]
  ) do |user|
    user.assign_attributes(attributes)
  end
end
