class ConfigurationsController < ApplicationController
  allow_unauthenticated_access

  def ios_v1
    render json: {
      settings: {},
      rules: [
        {
          patterns: [
            ".*"
          ],
          properties: {
            pull_to_refresh_enabled: true
          }
        },
        # 1. 일반적인 new/edit는 모달로 설정 (먼저 배치)
        {
          patterns: [
            "/new$",
            "/edit$"
          ],
          properties: {
            context: "modal",
            pull_to_refresh_enabled: false,
            modal_style: "medium",
            custom_detent_ratio: 0.6
          }
        },
        # 2. session/new는 뒤에 배치하고, context를 default로 덮어씌워 모달을 해제 (하단 탭바 숨김)
        {
          patterns: [
            "/session/new$",
            "/session$"
          ],
          properties: {
            context: "default", # 모달 설정을 일반 화면으로 덮어씀
            hide_navigation_bar: true,
            hides_bottom_bar: true,
            bounces: false,
            pull_to_refresh_enabled: false
          }
        },
        # 3. settings 화면은 탭바 유지
        {
          patterns: [
            "/settings$"
          ],
          properties: {
            context: "default",
            hide_navigation_bar: true,
            hides_bottom_bar: false,
            bounces: false,
            pull_to_refresh_enabled: false
          }
        },
        # 4. 메인/루트 화면에서는 상단 네비게이션 바 및 뒤로가기 버튼 숨김
        {
          patterns: [
            "^/rooms",
            "^/$"
          ],
          properties: {
            hide_navigation_bar: true,
            hides_back_button: true
          }
        }
      ]
    }
  end

  def android_v1
    render json: {
      settings: {},
      rules: [
        {
          patterns: [
            ".*"
          ],
          properties: {
            uri: "hotwire://fragment/web",
            pull_to_refresh_enabled: true
          }
        },
        # 1. 일반적인 new/edit는 모달로 설정 (먼저 배치)
        {
          patterns: [
            "/new$",
            "/edit$"
          ],
          properties: {
            context: "modal",
            pull_to_refresh_enabled: false,
            modal_style: "medium",
            custom_detent_ratio: 0.6
          }
        },
        # 2. session/new는 뒤에 배치하고, context를 default로 덮어씌워 모달을 해제 (하단 탭바 숨김)
        {
          patterns: [
            "/session/new$",
            "/session$"
          ],
          properties: {
            context: "default", # 모달 설정을 일반 화면으로 덮어씀
            hide_navigation_bar: true,
            hides_bottom_bar: true,
            bounces: false,
            pull_to_refresh_enabled: false
          }
        },
        # 3. settings 화면은 탭바 유지
        {
          patterns: [
            "/settings$"
          ],
          properties: {
            context: "default",
            hide_navigation_bar: true,
            hides_bottom_bar: false,
            bounces: false,
            pull_to_refresh_enabled: false
          }
        },
        # 4. 메인/루트 화면에서는 상단 네비게이션 바 및 뒤로가기 버튼 숨김
        {
          patterns: [
            "^/rooms",
            "^/$"
          ],
          properties: {
            hide_navigation_bar: true,
            hides_back_button: true
          }
        }
      ]
    }
  end
end
