# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardMetrics do
  let(:today) { Date.new(2026, 9, 24) }

  subject(:metrics) { described_class.new(today: today) }

  describe "volunteer totals" do
    it "counts everyone and splits out inactive volunteers" do
      create_list(:volunteer, 2, current_funnel_stage: :inquiry)
      create(:volunteer, current_funnel_stage: :inactive)

      expect(metrics.total_volunteers).to eq(3)
      expect(metrics.inactive_volunteers).to eq(1)
      expect(metrics.active_volunteers).to eq(2)
    end
  end

  describe "#volunteers_by_stage" do
    it "lists every stage in funnel order, including empty ones" do
      create_list(:volunteer, 2, current_funnel_stage: :inquiry)
      create(:volunteer, current_funnel_stage: :applied)

      expect(metrics.volunteers_by_stage).to eq(
        "inquiry" => 2, "application_eligible" => 0, "application_sent" => 0, "applied" => 1, "inactive" => 0
      )
    end
  end

  describe "#new_inquiries_this_month" do
    it "counts inquiry dates from the first of the month through today" do
      create(:volunteer, inquiry_date: Time.zone.parse("2026-09-01 08:00"))
      create(:volunteer, inquiry_date: Time.zone.parse("2026-09-24 20:00"))
      create(:volunteer, inquiry_date: Time.zone.parse("2026-08-31 23:00"))

      expect(metrics.new_inquiries_this_month).to eq(2)
    end

    it "falls back to when the volunteer was added if there's no inquiry date" do
      create(:volunteer, inquiry_date: nil, created_at: Time.zone.parse("2026-09-10 12:00"))
      create(:volunteer, inquiry_date: nil, created_at: Time.zone.parse("2026-08-10 12:00"))

      expect(metrics.new_inquiries_this_month).to eq(1)
    end

    it "uses the inquiry date over the created date when both are set" do
      create(:volunteer, inquiry_date: Time.zone.parse("2026-08-15 12:00"),
                         created_at: Time.zone.parse("2026-09-15 12:00"))

      expect(metrics.new_inquiries_this_month).to eq(0)
    end
  end

  describe "#inquiries_by_month" do
    it "covers the last 12 months through this month, with empty months as 0" do
      create(:volunteer, inquiry_date: Time.zone.parse("2025-10-01 09:00"))
      create(:volunteer, inquiry_date: Time.zone.parse("2026-02-10 12:00"))
      create(:volunteer, inquiry_date: Time.zone.parse("2026-02-20 12:00"))
      create(:volunteer, inquiry_date: nil, created_at: Time.zone.parse("2026-09-03 12:00"))
      create(:volunteer, inquiry_date: Time.zone.parse("2025-09-30 12:00")) # before the window, left out

      series = metrics.inquiries_by_month

      expect(series.size).to eq(12)
      expect(series.keys.first).to eq(Date.new(2025, 10, 1))
      expect(series.keys.last).to eq(Date.new(2026, 9, 1))
      expect(series[Date.new(2025, 10, 1)]).to eq(1)
      expect(series[Date.new(2026, 2, 1)]).to eq(2)
      expect(series[Date.new(2026, 9, 1)]).to eq(1)
      expect(series[Date.new(2026, 6, 1)]).to eq(0)
      expect(series.values.sum).to eq(4)
    end

    it "agrees with the new inquiries tile for the current month" do
      create(:volunteer, inquiry_date: Time.zone.parse("2026-09-05 12:00"))
      create(:volunteer, inquiry_date: nil, created_at: Time.zone.parse("2026-09-06 12:00"))

      expect(metrics.inquiries_by_month.values.last).to eq(metrics.new_inquiries_this_month)
    end
  end

  describe "awaiting submission" do
    it "counts volunteers with an application out and reports the longest wait" do
      create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: Time.zone.parse("2026-09-06 10:00"))
      create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: Time.zone.parse("2026-09-20 10:00"))
      create(:volunteer, current_funnel_stage: :applied, application_sent_at: Time.zone.parse("2026-08-01 10:00"))

      expect(metrics.awaiting_submission_count).to eq(2)
      expect(metrics.longest_submission_wait_days).to eq(18)
    end

    it "returns nil for the longest wait when nobody is waiting" do
      expect(metrics.awaiting_submission_count).to eq(0)
      expect(metrics.longest_submission_wait_days).to be_nil
    end
  end

  describe "#conversion_funnel" do
    let(:this_year) { Time.zone.parse("2026-03-01 12:00") }

    def counts
      metrics.conversion_funnel.to_h { |step| [ step.key, step.count ] }
    end

    it "counts each step from the date it was reached or the stage the volunteer is in" do
      create(:volunteer, inquiry_date: this_year)
      create(:volunteer, inquiry_date: this_year, first_session_attended_at: this_year)
      create(:volunteer, inquiry_date: this_year, current_funnel_stage: :application_eligible)
      create(:volunteer, inquiry_date: this_year, current_funnel_stage: :application_sent, application_sent_at: this_year)
      create(:volunteer, inquiry_date: this_year, current_funnel_stage: :applied)

      expect(counts).to eq(inquired: 5, attended: 4, application_sent: 2, applied: 1)
    end

    it "keeps the furthest step of volunteers who later went inactive" do
      create(:volunteer, inquiry_date: this_year, current_funnel_stage: :inactive,
                         application_sent_at: this_year, application_submitted_at: this_year)
      create(:volunteer, inquiry_date: this_year, current_funnel_stage: :inactive)

      expect(counts).to eq(inquired: 2, attended: 1, application_sent: 1, applied: 1)
    end

    it "only includes volunteers who inquired in the past 12 months" do
      create(:volunteer, inquiry_date: Time.zone.parse("2025-09-30 12:00"), current_funnel_stage: :applied)
      create(:volunteer, inquiry_date: nil, created_at: this_year)

      expect(counts).to eq(inquired: 1, attended: 0, application_sent: 0, applied: 0)
    end

    it "reports each step as a share of inquiries and of the step before" do
      create_list(:volunteer, 2, inquiry_date: this_year)
      create(:volunteer, inquiry_date: this_year, first_session_attended_at: this_year)
      create(:volunteer, inquiry_date: this_year, current_funnel_stage: :applied)

      inquired, attended, sent, applied = metrics.conversion_funnel

      expect(inquired).to have_attributes(share: 1.0, step_rate: nil)
      expect(attended).to have_attributes(count: 2, share: 0.5, step_rate: 0.5)
      expect(sent).to have_attributes(count: 1, share: 0.25, step_rate: 0.5)
      expect(applied).to have_attributes(count: 1, share: 0.25, step_rate: 1.0)
      expect(metrics.conversion_rate).to eq(0.25)
    end

    it "has no rates when nobody inquired" do
      expect(metrics.conversion_funnel.map(&:count)).to eq([ 0, 0, 0, 0 ])
      expect(metrics.conversion_rate).to be_nil
    end
  end

  describe "session attendance" do
    def past_session(scheduled_at, **attributes)
      build(:information_session, scheduled_at: scheduled_at, **attributes).tap { |session| session.save!(validate: false) }
    end

    def register(session, *statuses)
      statuses.each { |status| create(:session_registration, information_session: session, status: status) }
    end

    it "counts check-ins against everyone still registered for sessions in the past 90 days" do
      register(past_session(Time.zone.parse("2026-09-10 18:00")), :attended, :attended, :registered, :no_show)
      register(past_session(Time.zone.parse("2026-07-01 18:00")), :attended)

      expect(metrics.session_attendance).to have_attributes(attended: 3, expected: 5, rate: 0.6)
    end

    it "leaves out cancelled and rescheduled registrations" do
      register(past_session(Time.zone.parse("2026-09-10 18:00")), :attended, :cancelled, :rescheduled)

      expect(metrics.session_attendance).to have_attributes(attended: 1, expected: 1, rate: 1.0)
    end

    it "leaves out sessions older than 90 days and sessions that haven't happened yet" do
      register(past_session(Time.zone.parse("2026-06-20 18:00")), :attended, :registered)
      register(create(:information_session, scheduled_at: 3.days.from_now), :registered)

      expect(metrics.session_attendance).to have_attributes(attended: 0, expected: 0, rate: nil)
    end

    it "breaks attendance down by recent session, newest first" do
      older = past_session(Time.zone.parse("2026-08-05 18:00"))
      newer = past_session(Time.zone.parse("2026-09-15 18:00"))
      empty = past_session(Time.zone.parse("2026-09-01 18:00"))
      register(older, :attended, :registered, :registered, :cancelled)
      register(newer, :attended, :attended)

      rows = metrics.recent_session_attendance.map { |session, attendance| [ session, attendance.attended, attendance.expected ] }

      expect(rows).to eq([ [ newer, 2, 2 ], [ empty, 0, 0 ], [ older, 1, 3 ] ])
    end
  end

  describe "upcoming sessions" do
    it "counts future sessions and returns the soonest one" do
      later = create(:information_session, scheduled_at: 5.days.from_now)
      sooner = create(:information_session, scheduled_at: 2.days.from_now)
      past = build(:information_session, scheduled_at: 2.days.ago)
      past.save!(validate: false)

      expect(metrics.upcoming_sessions_count).to eq(2)
      expect(metrics.next_session).to eq(sooner)
      expect(metrics.next_session).not_to eq(later)
    end

    it "has no next session when nothing is scheduled" do
      expect(metrics.upcoming_sessions_count).to eq(0)
      expect(metrics.next_session).to be_nil
    end
  end
end
