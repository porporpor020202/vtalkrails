module ApplicationHelper
  def dev_mode?
    Rails.env.development?
  end
end
