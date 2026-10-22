module ApplicationDashboardHelper
  CHART_COLOR = "#2a78d6"
  CHART_TEXT_COLOR = "#4b5563" # gray-600, same as other secondary text
  CHART_GRID_COLOR = "#e5e7eb" # gray-200

  # Shared Chartkick settings
  def dashboard_chart_options(horizontal: false, category_labels: nil)
    value_axis, category_axis = horizontal ? %i[x y] : %i[y x]
    category_scale = { grid: { display: false }, ticks: { color: CHART_TEXT_COLOR, autoSkip: false, maxRotation: 0 } }
    category_scale[:labels] = category_labels if category_labels

    {
      colors: [ CHART_COLOR ],
      height: "240px",
      dataset: {
        backgroundColor: CHART_COLOR, borderWidth: 0,
        borderRadius: 4, borderSkipped: "start", maxBarThickness: 24
      },
      library: {
        scales: {
          value_axis => { grid: { color: CHART_GRID_COLOR }, ticks: { color: CHART_TEXT_COLOR, precision: 0 } },
          category_axis => category_scale
        }
      }
    }
  end

  # Monthly counts keyed by month and year
  def month_chart_data(counts_by_month)
    counts_by_month.transform_keys { |month| month.strftime("%b '%y") }
  end

  # Month names drawn under the bars
  def month_axis_labels(counts_by_month)
    counts_by_month.keys.map { |month| month.strftime("%b") }
  end

  def month_range_label(counts_by_month)
    first, last = counts_by_month.keys.minmax
    "#{first.strftime('%b %Y')} – #{last.strftime('%b %Y')}"
  end

  FUNNEL_STEP_LABELS = {
    inquired: "Inquired",
    attended: "Attended an info session",
    application_sent: "Application sent",
    applied: "Applied"
  }.freeze

  # A 0–1 rate as a whole percent, or a dash when there's nothing to divide by
  def dashboard_percent(rate)
    rate ? number_to_percentage(rate * 100, precision: 0) : "—"
  end

  # Width for a meter's filled bar
  def meter_fill_style(rate)
    "width: #{((rate || 0) * 100).round(1)}%"
  end

  def session_attendance_label(session)
    "#{session.scheduled_at.strftime('%b %-d')} · #{session.virtual? ? 'Virtual' : 'In person'}"
  end

  def stage_chart_data(counts_by_stage)
    counts_by_stage.to_h do |stage, count|
      [ "#{VolunteersHelper::STATUS_BADGE_LABELS.fetch(stage)} (#{number_with_delimiter(count)})", count ]
    end
  end
end
