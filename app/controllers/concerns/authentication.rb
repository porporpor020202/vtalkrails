module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def current_user
      Current.user
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.encrypted[:session_id]) if cookies.encrypted[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end


    def start_new_session_for(user)
      training_usage = AiUsage.claim!(user: user, visitor_id: cookies.encrypted[:ai_visitor_id])
      if NativeLanguage.supported?(cookies[:native_language]) && user.native_language != cookies[:native_language]
        user.update!(native_language: cookies[:native_language])
      end
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        claimed_practice = claim_guest_practice(user, training_usage: training_usage)
        Current.session = session
        cookies.encrypted.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
        link_marketing_account(user, session_record: session)
        track_marketing("guest_recording_claimed", key: "claim:#{claimed_practice.id}") if claimed_practice
      end
    end

    def claim_guest_practice(user, training_usage:)
      id = session[:guest_practice_id] || cookies.encrypted[:apple_guest_practice_id]
      return unless id

      claimed_practice = nil
      user.with_lock do
        practice = DailyPractice.find_by(id: id, user_id: nil)
        practice&.with_lock do
          next if practice.user_id.present?
          next unless training_usage.reload.available_on?(practice.practiced_on)

          if user.daily_practices.exists?(practiced_on: practice.practiced_on)
            practice.destroy!
          else
            practice.update!(user: user)
            claimed_practice = practice
            session[:practice_saved] = true
          end
        end
      end
      session.delete(:guest_practice_id)
      cookies.delete(:apple_guest_practice_id, same_site: :none, secure: Rails.env.production? || request.ssl?)
      claimed_practice
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(:session_id)
    end
end
