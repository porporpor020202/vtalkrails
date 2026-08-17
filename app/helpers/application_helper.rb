module ApplicationHelper
  def dev_mode?
    request.host.start_with?("dev.") || request.host.include?("dev.vtalks") || Rails.env.development?
  end

  def nav_tab_class(path)
    if current_page?(path)
      "text-indigo-400 font-semibold"
    else
      "text-zinc-500 hover:text-zinc-300 font-medium"
    end
  end

  def sprite_tag(name, **options)
    content_tag(:svg, **options) do
      # "<use xlink:href=\"#{image_path("sprite-sheet.svg")}##{name}\">".html_safe
    end
  end

  def icon_tag(name, size:, **options)
    class_name = [ "#{size}-icon", options.delete(:class) ].compact.join(" ")
    sprite_tag(name, **options.merge(class: class_name, aria: { hidden: "true" }))
  end
end
