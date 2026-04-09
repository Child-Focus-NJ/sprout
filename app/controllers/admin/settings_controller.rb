module Admin
  class SettingsController < ApplicationController
    before_action :require_admin!

    REMINDER_INTERVAL_WEEKS = [ 1, 2, 4, 8, 12 ].freeze

    def index
      raw = SystemSetting.get("application_reminder_interval_weeks")
      w = raw.present? ? raw.to_i : 2
      @reminder_interval_weeks = REMINDER_INTERVAL_WEEKS.include?(w) ? w : 2
    end

    def update
      weeks = params[:application_reminder_interval_weeks].to_i
      weeks = 2 unless REMINDER_INTERVAL_WEEKS.include?(weeks)

      SystemSetting.set(
        "application_reminder_interval_weeks",
        weeks,
        type: :integer,
        description: "Weeks between application reminder emails for volunteers awaiting submission.",
        user: current_user
      )

      redirect_to admin_settings_path(anchor: "application-reminders"),
                  notice: "Reminder interval saved."
    end
  end
end
