# frozen_string_literal: true

require "rails_helper"

RSpec.describe VolunteersHelper, type: :helper do
  describe "#volunteer_status_badge" do
    {
      inquiry: [ "Inquiry", "status-badge--inquiry" ],
      application_eligible: [ "Application eligible", "status-badge--application-eligible" ],
      application_sent: [ "Application sent", "status-badge--application-sent" ],
      applied: [ "Applied", "status-badge--applied" ],
      inactive: [ "Inactive", "status-badge--inactive" ]
    }.each do |stage, (label, css_class)|
      it "renders a #{stage} badge" do
        volunteer = build(:volunteer, current_funnel_stage: stage)
        badge = helper.volunteer_status_badge(volunteer)

        expect(badge).to include(label)
        expect(badge).to include("status-badge")
        expect(badge).to include(css_class)
        expect(badge).to include("title=\"Status: #{label}\"")
      end
    end
  end

  describe "#volunteer_status_color_class" do
    it "returns the badge color modifier for a stage" do
      expect(helper.volunteer_status_color_class("application_sent")).to eq("status-badge--application-sent")
    end
  end

  describe "#volunteer_status_options" do
    it "lists every funnel stage with the same wording as the badges" do
      expect(helper.volunteer_status_options).to eq([
        [ "Inquiry", "inquiry" ],
        [ "Application eligible", "application_eligible" ],
        [ "Application sent", "application_sent" ],
        [ "Applied", "applied" ],
        [ "Inactive", "inactive" ]
      ])
    end
  end

  describe "#missed_sessions_flag" do
    let(:volunteer) { build_stubbed(:volunteer) }

    it "lists each way they missed a session, leaving out ones that didn't happen" do
      flag = helper.missed_sessions_flag({ [ volunteer.id, "no_show" ] => 2, [ volunteer.id, "rescheduled" ] => 1 }, volunteer)

      expect(flag).to include("2 no-shows · 1 reschedule")
      expect(flag).to include("missed-sessions-flag")
    end

    it "spells out cancellations" do
      flag = helper.missed_sessions_flag({ [ volunteer.id, "no_show" ] => 1, [ volunteer.id, "cancelled" ] => 1 }, volunteer)

      expect(flag).to include("1 no-show · 1 cancellation")
    end

    it "shows nothing for a single missed session" do
      expect(helper.missed_sessions_flag({ [ volunteer.id, "cancelled" ] => 1 }, volunteer)).to be_nil
    end
  end

  describe "#timeline_entry_label" do
    it "spells SMS in capitals and humanizes other kinds" do
      expect(helper.timeline_entry_label(:sms)).to eq("SMS")
      expect(helper.timeline_entry_label(:status_change)).to eq("Status change")
      expect(helper.timeline_entry_label(:info_session)).to eq("Info session")
    end
  end
end
