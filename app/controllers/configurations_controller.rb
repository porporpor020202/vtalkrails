class ConfigurationsController < ApplicationController
  allow_unauthenticated_access

  def ios_v1
    render json: {
       settings: {},
       rules: [
         {
           patterns: [
             "/session/new$"
           ],
           properties: {
             context: "modal",
             modal_style: "full"
           }
         },
         {
           patterns: [
             "/modal/new$"
           ],
           properties: {
             context: "modal",
             modal_style: "full"
           }
         },
         {
           patterns: [
             "/numbers$"
           ],
           properties: {
             view_controller: "numbers"
           },
           comment: "It's IOS Comment"
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
            context: "default",
            uri: "hotwire://fragment/web",
            fallback_uri: "hotwire://fragment/web",
            pull_to_refresh_enabled: true
          }
        },
        {
          patterns: [
            "/session/new$"
          ],
          properties: {
            context: "modal"
          }
        },
        {
          patterns: [
            "/modal/new$"
          ],
          properties: {
            context: "modal",
            hide_navigation_bar: true
          }
        },
        {
          patterns: [
            "/numbers$"
          ],
          properties: {
            uri: "hotwire://fragment/numbers",
            title: "Numbers",
            comment: "It's Android Comment"
          }
        }
      ]
    }
  end

  # def ios_v1
  #   render json: {
  #     settings: {},
  #     rules: [
  #       {
  #         patterns: [
  #           ".*"
  #         ],
  #         properties: {
  #           pull_to_refresh_enabled: true
  #         }
  #       },
  #       # 1. 일반적인 new/edit는 모달로 설정 (먼저 배치)
  #       {
  #         patterns: [
  #           "/new$",
  #           "/edit$"
  #         ],
  #         properties: {
  #           context: "modal",
  #           pull_to_refresh_enabled: false,
  #           modal_style: "medium",
  #           custom_detent_ratio: 0.6
  #         }
  #       },
  #       # 2. session/new는 모달로 설정
  #       {
  #         patterns: [
  #           "/session/new$",
  #           "/session$"
  #         ],
  #         properties: {
  #           context: "modal",
  #           hide_navigation_bar: true,
  #           hides_bottom_bar: true,
  #           bounces: false,
  #           pull_to_refresh_enabled: false
  #         }
  #       },
  #       # 3. settings 화면은 탭바 유지
  #       {
  #         patterns: [
  #           "/settings$"
  #         ],
  #         properties: {
  #           context: "default",
  #           hide_navigation_bar: true,
  #           hides_bottom_bar: false,
  #           bounces: false,
  #           pull_to_refresh_enabled: false
  #         }
  #       },
  #       # 4. 메인/루트 화면에서는 상단 네비게이션 바 및 뒤로가기 버튼 숨김
  #       {
  #         patterns: [
  #           "^/rooms",
  #           "^/$"
  #         ],
  #         properties: {
  #           hide_navigation_bar: true,
  #           hides_back_button: true
  #         }
  #       }
  #     ]
  #   }
  # end
  #
  # def android_v1
  #   render json: {
  #     settings: {},
  #     rules: [
  #       {
  #         patterns: [
  #           ".*"
  #         ],
  #         properties: {
  #           uri: "hotwire://fragment/web",
  #           pull_to_refresh_enabled: true
  #         }
  #       },
  #       # 1. 일반적인 new/edit는 모달로 설정 (먼저 배치)
  #       {
  #         patterns: [
  #           "/new$",
  #           "/edit$"
  #         ],
  #         properties: {
  #           context: "modal",
  #           pull_to_refresh_enabled: false,
  #           modal_style: "medium",
  #           custom_detent_ratio: 0.6
  #         }
  #       },
  #       # 2. session/new는 모달로 설정 (replace_root와 modal은 함께 사용 불가)
  #       {
  #         patterns: [
  #           "/session/new$",
  #           "/session$"
  #         ],
  #         properties: {
  #           context: "modal",
  #         hide_navigation_bar: true,
  #           pull_to_refresh_enabled: false
  #         }
  #       },
  #       # 3. settings 화면은 탭바 유지
  #       {
  #         patterns: [
  #           "/settings$"
  #         ],
  #         properties: {
  #           context: "default",
  #           hide_navigation_bar: true,
  #           hides_bottom_bar: false,
  #           bounces: false,
  #           pull_to_refresh_enabled: false
  #         }
  #       },
  #       # 4. 메인/루트 화면에서는 상단 네비게이션 바 및 뒤로가기 버튼 숨김
  #       {
  #         patterns: [
  #           "^/rooms",
  #           "^/$"
  #         ],
  #         properties: {
  #           hide_navigation_bar: true,
  #           hides_back_button: true
  #         }
  #       }
  #     ]
  #   }
  # end
end
