# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteers index status badges", type: :request do
  let(:user) { create(:user, role: :admin) }

  before { login_as(user, scope: :user) }

  it "shows color-coded status badges for each funnel stage" do
    create(:volunteer, first_name: "Harry", last_name: "Kane", email: "harry@example.com", current_funnel_stage: :inquiry)
    create(:volunteer, first_name: "Sofia", last_name: "Reyes", email: "sofia@example.com", current_funnel_stage: :application_sent)
    create(:volunteer, first_name: "Hana", last_name: "Kimura", email: "hana@example.com", current_funnel_stage: :application_eligible)

    get volunteers_path

    expect(response).to be_successful
    expect(response.body).to include('class="status-badge status-badge--inquiry"')
    expect(response.body).to include('class="status-badge status-badge--application-sent"')
    expect(response.body).to include('class="status-badge status-badge--application-eligible"')
    expect(response.body).to include("Inquiry")
    expect(response.body).to include("Application sent")
    expect(response.body).to include("Application eligible")
    expect(response.body).to include('title="Status: Inquiry"')
  end

  it "shows the status badge on the volunteer profile header" do
    volunteer = create(
      :volunteer,
      first_name: "Hana",
      last_name: "Kimura",
      email: "hana.profile@example.com",
      current_funnel_stage: :application_eligible
    )

    get volunteer_path(volunteer)

    expect(response).to be_successful
    expect(response.body).to include("volunteer-profile-header")
    expect(response.body).to include("Hana Kimura")
    expect(response.body).to include('class="status-badge status-badge--application-eligible"')
    expect(response.body).to include("Application eligible")
  end
end
