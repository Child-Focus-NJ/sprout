class ReportingExportingController < ApplicationController
  def index
  end

  def export_report
    title = params["Title"].presence || "report"
    y_axis = params["y-axis"]
    start_date = parse_iso_date(params["Start Date"])
    end_date = parse_iso_date(params["End Date"])

    if start_date && end_date && start_date > end_date
      return redirect_to reporting_exporting_index_path, alert: "Start Date cannot be after End Date"
    end

    if start_date && end_date
      window_starts = []
      next_start = start_date
      begin
        window_starts << next_start
        next_start += 1.year
      end while next_start < end_date

      bars = window_starts.each_with_index.map do |range_start, i|
        range_end = i == window_starts.length - 1 ? end_date : window_starts[i + 1] - 1.day
        count = if y_axis == "applications"
          Volunteer.where(application_submitted_at: range_start..range_end).count
        else
          Volunteer.where(inquiry_date: range_start..range_end).count
        end

        full_calendar_year = range_start.month == 1 && range_start.day == 1 &&
          range_end.month == 12 && range_end.day == 31 && range_start.year == range_end.year

        label = if full_calendar_year
          range_start.year.to_s
        elsif range_start.year == range_end.year
          "#{range_start.strftime('%b %-d')} - #{range_end.strftime('%b %-d, %Y')}"
        else
          "#{range_start.strftime('%b %-d, %Y')} - #{range_end.strftime('%b %-d, %Y')}"
        end

        [ label, count ]
      end

      labels = bars.map(&:first)
      counts = bars.map(&:last)

      pdf = Prawn::Document.new

      pdf.image Rails.root.join("app", "assets", "images", "child_focus_logo.jpg").to_s, width: 100, position: :center
      pdf.move_down 20

      pdf.text title, size: 18, style: :bold
      pdf.move_down 20

      chart_width = 400
      chart_height = 200
      slot_width = chart_width.to_f / labels.length
      gap = [ slot_width * 0.2, 10 ].min
      bar_width = [ slot_width - gap, 2 ].max
      max_count = counts.max.to_f.nonzero? || 1.0
      base_y = pdf.cursor - chart_height

      labels.each_with_index do |label, i|
        bar_height = (counts[i] / max_count) * chart_height
        x = 50 + i * slot_width
        y = base_y + bar_height

        pdf.fill_color "4A90D9"
        pdf.fill_rectangle [ x, y ], bar_width, bar_height

        pdf.fill_color "000000"
        pdf.draw_text label, at: [ x, base_y - 15 ], size: 10
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
