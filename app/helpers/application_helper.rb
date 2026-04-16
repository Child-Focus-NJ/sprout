module ApplicationHelper
  # Up-level navigation: chevron + label (dashboard-style “return to parent” link).
  def back_nav_link(path, label)
    link_to path, class: "nav-back" do
      safe_join([
        tag.span("←", class: "nav-back__chevron", aria: { hidden: true }),
        tag.span(label)
      ])
    end
  end

  # Bust browser caches for static files in /public (favicons) when the file changes.
  def public_asset_version(relative_filename)
    path = Rails.root.join("public", relative_filename.to_s.delete_prefix("/"))
    File.exist?(path) ? File.mtime(path).to_i : Time.current.to_i
  end

  def app_nav_link_class(path)
    base = "app-navbar__link"
    current_page?(path) ? "#{base} app-navbar__link--active" : base
  end
end
