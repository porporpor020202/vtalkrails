module ApplicationHelper
  def dev_mode?
    request.host.start_with?("dev.") || request.host.include?("dev.vtalks") || Rails.env.development?
  end
end
