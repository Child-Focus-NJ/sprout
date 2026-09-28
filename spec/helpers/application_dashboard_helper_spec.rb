# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationDashboardHelper, type: :helper do
  describe "#stage_chart_data" do
    it "labels each stage like its badge, with the count in the label" do
      data = helper.stage_chart_data("inquiry" => 1204, "application_sent" => 2, "inactive" => 0)

      expect(data).to eq("Inquiry (1,204)" => 1204, "Application sent (2)" => 2, "Inactive (0)" => 0)
    end
  end

  describe "monthly chart labels" do
    let(:series) do
      (0..12).to_h { |i| [ Date.new(2025, 9, 1) >> i, i ] }
    end

    it "labels every month with month and year, keeping both Septembers as separate bars" do
      data = helper.month_chart_data(series)

      expect(data.size).to eq(13)
      expect(data.keys.first(5)).to eq([ "Sep '25", "Oct '25", "Nov '25", "Dec '25", "Jan '26" ])
      expect(data.keys.last).to eq("Sep '26")
      expect(data["Sep '25"]).to eq(0)
      expect(data["Sep '26"]).to eq(12)
    end

    it "shows just the month name on the axis" do
      expect(helper.month_axis_labels(series)).to eq(%w[Sep Oct Nov Dec Jan Feb Mar Apr May Jun Jul Aug Sep])
    end

    it "describes the range the series covers, with years" do
      expect(helper.month_range_label(series)).to eq("Sep 2025 – Sep 2026")
    end
  end

  describe "#dashboard_chart_options" do
    it "draws every category label flat, never skipping any" do
      ticks = helper.dashboard_chart_options[:library][:scales][:x][:ticks]

      expect(ticks).to include(autoSkip: false, maxRotation: 0)
    end

    it "uses the given axis labels in place of the data labels" do
      scales = helper.dashboard_chart_options(category_labels: %w[Sep Oct])[:library][:scales]

      expect(scales[:x][:labels]).to eq(%w[Sep Oct])
      expect(helper.dashboard_chart_options[:library][:scales][:x]).not_to have_key(:labels)
    end

    it "puts gridlines on the value axis only" do
      column = helper.dashboard_chart_options[:library][:scales]
      bar = helper.dashboard_chart_options(horizontal: true)[:library][:scales]

      expect(column[:y][:grid]).to include(color: ApplicationDashboardHelper::CHART_GRID_COLOR)
      expect(column[:x][:grid]).to eq(display: false)
      expect(bar[:x][:grid]).to include(color: ApplicationDashboardHelper::CHART_GRID_COLOR)
      expect(bar[:y][:grid]).to eq(display: false)
    end

    it "draws solid bars capped at 24px" do
      dataset = helper.dashboard_chart_options[:dataset]

      expect(dataset).to include(backgroundColor: ApplicationDashboardHelper::CHART_COLOR, borderWidth: 0, maxBarThickness: 24)
    end
  end
end
