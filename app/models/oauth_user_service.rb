class OauthUserService
  def self.find_or_create(oauth_provider:, current_user: nil, uid:, email:)
    user = User.find_by(oauth_provider: oauth_provider, oauth_uid: uid)
    return user if user

    if current_user&.guest?
      current_user.update(
        oauth_provider: oauth_provider,
        oauth_uid: uid,
        email_address: email,
        guest: false
      )
      return current_user
    end

    User.create(
      oauth_provider: oauth_provider,
      oauth_uid: uid,
      email_address: email,
      guest: false
    )
  end
end
