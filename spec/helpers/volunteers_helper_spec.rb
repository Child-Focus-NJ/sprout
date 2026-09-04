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
end
