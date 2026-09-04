class SystemManagementController < ApplicationController
  TABS = %w[frequencies tags employees referral_sources].freeze

  def show
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "frequencies"
    @users = User.where.not(id: current_user.id).order(:last_name, :first_name)
    @reminder_frequencies = ReminderFrequency.order(:title)
    @volunteer_tags = VolunteerTag.order(:title)
    @referral_sources = ReferralSource.order(:name)
    @recent_syncs = ExternalSyncLog
                      .completed
                      .where("completed_at > ?", 24.hours.ago)
                      .includes(:volunteer)
                      .order(completed_at: :desc)
  end

  def import
    file = params[:file]
    if file.present?
      VolunteerImportService.call(file.path)
      redirect_to system_management_path, notice: "Import complete."
    else
      redirect_to system_management_path, alert: "No file selected."
    end
  end

  def export_data
    title = params["Title"].presence || "export"
    export_format = params["export format"]
    status_filter = params["Status"]
    start_date = Date.strptime(params["Start Date"], "%m/%d/%Y") rescue nil
    end_date = Date.strptime(params["End Date"], "%m/%d/%Y") rescue nil

    volunteers = Volunteer.all

    if status_filter == "Attended an Information Session"
      volunteers = volunteers.where.not(first_session_attended_at: nil)
    elsif status_filter.present?
      stage = Volunteer.current_funnel_stages[status_filter.downcase.gsub(" ", "_")]
      volunteers = volunteers.where(current_funnel_stage: stage) if stage
    end

  if start_date && end_date
    if status_filter == "Attended an Information Session"
      volunteers = volunteers.where(first_session_attended_at: start_date..end_date)
    elsif status_filter == "Applied"
      volunteers = volunteers.where(application_submitted_at: start_date..end_date)
    elsif status_filter == "Application Sent"
      volunteers = volunteers.where(application_sent_at: start_date..end_date)
    elsif status_filter == "Inactive"
      volunteers = volunteers.where(became_inactive_at: start_date..end_date)
    else
      volunteers = volunteers.where(inquiry_date: start_date..end_date)
    end
  end

    if export_format == "Excel"
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Data") do |sheet|
        sheet.add_row [ "Name", "Email", "Status" ]
        volunteers.each do |v|
          status_label = v.first_session_attended_at.present? ? "Attended an Information Session" : v.current_funnel_stage.humanize
          sheet.add_row [ v.full_name, v.email, status_label ]
        end
      end

      if Rails.env.test?
        File.binwrite(Rails.root.join("tmp", "test_downloads", "#{title}.xlsx"), package.to_stream.read)
        head :ok


      else
        send_data package.to_stream.read,
          filename: "#{title}.xlsx",
          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          disposition: "attachment"
      end
    end
  end
end
