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
        # 2. session/new는 뒤에 배치하고, context를 default로 덮어씌워 모달을 해제
        {
          patterns: [
            "/session/new$",
            "/session$",
            "/settings$"
          ],
          properties: {
            context: "default", # 모달 설정을 일반 화면으로 덮어씀
            hide_navigation_bar: true,
            pull_to_refresh_enabled: false
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
        # 2. session/new는 뒤에 배치하고, context를 default로 덮어씌워 모달을 해제
        {
          patterns: [
            "/session/new$",
            "/session$",
            "/settings$"
          ],
          properties: {
            context: "default", # 모달 설정을 일반 화면으로 덮어씀
            hide_navigation_bar: true,
            pull_to_refresh_enabled: false
          }
        }
      ]
    }
  end
end
