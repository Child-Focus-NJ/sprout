module ApplicationHelper
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
