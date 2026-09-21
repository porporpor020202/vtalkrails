class OauthUserService
  def self.find_or_create(oauth_provider:, uid:, email:)
    # Serialize nickname allocation and duplicate requests for one identity.
    User.transaction do
      User.connection.execute("SELECT pg_advisory_xact_lock(7951, 1)")
      User.find_or_create_by!(oauth_provider: oauth_provider, oauth_uid: uid) do |user|
        user.email_address = email
      end
    end
  end
end
