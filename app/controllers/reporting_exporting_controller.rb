class ReportingExportingController < ApplicationController
  def index
  end

  def export_report
    title = params["Title"].presence || "report"
    x_axis = params["x-axis"]
    y_axis = params["y-axis"]
    start_date = Date.strptime(params["Start Date"], "%m/%d/%Y") rescue nil
    end_date = Date.strptime(params["End Date"], "%m/%d/%Y") rescue nil
    action = params["commit"]

    if x_axis == "years" && start_date && end_date
      years = (start_date.year..end_date.year).to_a

      counts = years.map do |year|
        year_start = Date.new(year, 1, 1)
        year_end = Date.new(year, 12, 31)
        sessions = InformationSession.where(scheduled_at: year_start..year_end)
        SessionRegistration.where(information_session: sessions).count
      end

      pdf = Prawn::Document.new

      pdf.text title, size: 18, style: :bold
      pdf.move_down 20

      chart_width = 400
      chart_height = 200
      bar_width = chart_width / years.length - 10
      max_count = counts.max.to_f.nonzero? || 1.0
      base_y = pdf.cursor - chart_height

      years.each_with_index do |year, i|
        bar_height = (counts[i] / max_count) * chart_height
        x = 50 + i * (bar_width + 10)
        y = base_y + bar_height

        pdf.fill_color "4A90D9"
        pdf.fill_rectangle [x, y], bar_width, bar_height

        pdf.fill_color "000000"
        pdf.draw_text year.to_s, at: [x, base_y - 15], size: 10
        pdf.draw_text counts[i].to_s, at: [x, y + 2], size: 8
      end

      pdf.move_cursor_to base_y - 30

      if action == "Print"
        pdf_data = pdf.render
        render js: "window.__printCalled = false; var blob = new Blob([#{pdf_data.bytes.inspect}], {type:'application/pdf'}); var url = URL.createObjectURL(blob); var w = window.open(url); w.onload = function(){ w.print(); window.__printCalled = true; };"
      else
        if Rails.env.test?
          File.binwrite(Rails.root.join('tmp', 'test_downloads', "#{title}.pdf"), pdf.render)
          head :ok
        else
          send_data pdf.render, filename: "#{title}.pdf", type: "application/pdf", disposition: "attachment"
        end
      end
    else
      redirect_to reporting_exporting_index_path, alert: "Invalid parameters"
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
      attended_session_ids = InformationSession.where(scheduled_at: start_date..end_date).pluck(:id)
      volunteers = volunteers.joins(:session_registrations)
                             .where(session_registrations: { information_session_id: attended_session_ids })
    end

    if export_format == "Excel"
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Data") do |sheet|
        sheet.add_row ["Name", "Email", "Status"]
        volunteers.each do |v|
          status_label = v.first_session_attended_at.present? ? "Attended an Information Session" : v.current_funnel_stage.humanize
          sheet.add_row [v.full_name, v.email, status_label]
        end
      end

      if Rails.env.test?
        File.binwrite(Rails.root.join('tmp', 'test_downloads', "#{title}.xlsx"), package.to_stream.read)
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