class AdminPolicy
  def initialize(user, _record)
    @user = user
  end

  def access?
    @user&.admin?
  end
end
