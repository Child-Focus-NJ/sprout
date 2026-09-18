module Admin
  class SettingsController < ApplicationController
    before_action :require_admin!

    REMINDER_INTERVAL_WEEKS = [ 1, 2, 4, 8, 12 ].freeze

    def index
      load_settings
    end

    def update
      return update_application_link if params.key?(:application_url)

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

    private

    def load_settings
      raw = SystemSetting.get("application_reminder_interval_weeks")
      w = raw.present? ? raw.to_i : 2
      @reminder_interval_weeks = REMINDER_INTERVAL_WEEKS.include?(w) ? w : 2
      @application_url = SystemSetting.get("application_url")
    end

    def update_application_link
      SystemSetting.set(
        "application_url", params[:application_url].to_s.strip,
        description: "Application link included in manual and automatic application emails.",
        user: current_user
      )
      redirect_to admin_settings_path(anchor: "application-email"), notice: "Application link saved."
    rescue ActiveRecord::RecordInvalid => e
      load_settings
      @application_url = params[:application_url].to_s
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end
end
