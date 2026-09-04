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
        if y_axis == "applications"
          Volunteer.where(application_submitted_at: year_start..year_end).count
        else
          Volunteer.where(inquiry_date: year_start..year_end).count
        end
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
        pdf.fill_rectangle [ x, y ], bar_width, bar_height

        pdf.fill_color "000000"
        pdf.draw_text year.to_s, at: [ x, base_y - 15 ], size: 10
        pdf.draw_text counts[i].to_s, at: [ x, y + 2 ], size: 8
      end

      pdf.move_cursor_to base_y - 30


    if Rails.env.test?
      File.binwrite(Rails.root.join("tmp", "test_downloads", "#{title}.pdf"), pdf.render)
      head :ok
    else
      send_data pdf.render, filename: "#{title}.pdf", type: "application/pdf", disposition: "attachment"
    end

    else
      redirect_to reporting_exporting_index_path, alert: "Invalid parameters"
    end
  end
end
