module ApplicationHelper
  # External VMS root URL for "VMS" link in main navigation (opens the third-party site; no sync).
  DEFAULT_VMS_URL = "https://nj-passaic.evintosolutions.com/Account/LogOn"
  VMS_URL_ENV_KEY = "EXTERNAL_VMS_URL"

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

  def vms_url
    ENV.fetch(VMS_URL_ENV_KEY, DEFAULT_VMS_URL).to_s.sub(%r{/+\z}, "")
  end

  # alert_count adds a red count after the label, for things waiting on staff
  def system_management_tab_link(label, tab, current_tab, alert_count: 0)
    classes = "sys-tabs__link"
    classes += " sys-tabs__link--active" if tab == current_tab
    link_to system_management_path(tab: tab), class: classes do
      count = tag.span(alert_count, class: "sys-tabs__alert-count") if alert_count.positive?
      safe_join([ label, count ].compact, " ")
    end
  end

  # Red dot on the Admin link while Admin > Possible Duplicates has pairs to check
  def possible_duplicates_to_review?
    return @possible_duplicates_to_review if defined?(@possible_duplicates_to_review)

    @possible_duplicates_to_review = current_user&.admin? && PossibleDuplicates.any?
  end

  def employee_active_toggle_params(user, active:)
    { first_name: user.first_name, last_name: user.last_name, email: user.email, role: user.role, active: active }
  end
end
