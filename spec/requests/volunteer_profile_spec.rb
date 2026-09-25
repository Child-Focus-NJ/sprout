# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer profile page", type: :request do
  let(:user) { create(:user, first_name: "Pat", last_name: "Admin") }
  let(:volunteer) do
    create(:volunteer, first_name: "Sofia", last_name: "Reyes", current_funnel_stage: :inquiry,
                       email: "profile-spec@childfocusnj.org")
  end

  before { login_as(user, scope: :user) }

  def page_html
    response.parsed_body
  end

  it "no longer renders the cards that repeated other information" do
    volunteer.change_status!(:application_eligible, user: user)
    volunteer.communications.create!(communication_type: :sms, body: "Hi", sent_at: Time.current, status: :delivered)

    get volunteer_path(volunteer)

    headings = page_html.css("h2").map { |h| h.text.strip }
    expect(headings).to eq([ "Contact", "Actions", "Timeline" ])
    %w[#volunteer-status #application-info #applied-section #status-history #communications].each do |selector|
      expect(page_html.at_css(selector)).to be_nil, "expected #{selector} to be gone"
    end
  end

  it "keeps the status badge and the status update control" do
    get volunteer_path(volunteer)

    expect(page_html.at_css(".volunteer-profile-header .status-badge--inquiry")).to be_present
    expect(page_html.at_css("select#status option[selected]")["value"]).to eq("inquiry")
    expect(page_html.at_css("#status-management button").text).to eq("Update status")
  end

  it "shows application sent and submitted dates under the name" do
    volunteer.update!(current_funnel_stage: :applied,
                      application_sent_at: Time.zone.parse("2026-02-21 10:00"),
                      application_submitted_at: Time.zone.parse("2026-03-02 10:00"))

    get volunteer_path(volunteer)

    dates = page_html.at_css(".volunteer-profile-header #application-dates").text.squish
    expect(dates).to eq("Application sent 2026-02-21 Application submitted 2026-03-02")
  end

  it "leaves out the dates line before an application goes out" do
    get volunteer_path(volunteer)

    expect(page_html.at_css("#application-dates")).to be_nil
  end

  it "shows status changes in the timeline with who made them and when" do
    volunteer.change_status!(:application_eligible, user: user)

    get volunteer_path(volunteer)

    entry = page_html.at_css(".timeline .status-change-entry")
    expect(entry.at_css(".content").text.strip).to eq("Inquiry → Application eligible")
    expect(entry.at_css(".entry__byline").text.strip).to eq("By Pat Admin")
    expect(entry["data-timestamp"]).to be_present
  end

  it "shows SMS delivery status in the timeline" do
    volunteer.communications.create!(communication_type: :sms, body: "See you Saturday",
                                     sent_at: Time.current, status: :delivered)

    get volunteer_path(volunteer)

    entry = page_html.at_css(".timeline .sms-entry")
    expect(entry.at_css("strong").text).to eq("SMS")
    expect(entry.at_css(".delivery-status").text.strip).to eq("delivered")
    expect(entry.at_css(".content").text.strip).to eq("See you Saturday")
  end

  it "filters the timeline to status changes" do
    volunteer.add_staff_note!(content: "Left a voicemail", user: user)
    volunteer.change_status!(:application_eligible, user: user)

    get volunteer_path(volunteer, filter: "status_changes")

    entry_classes = page_html.css(".timeline .entry").map { |e| e["class"] }
    expect(entry_classes).not_to be_empty
    expect(entry_classes).to all(include("status-change-entry"))
    expect(page_html.at_css('select#filter option[value="status_changes"][selected]')).to be_present
    expect(response.body).not_to include("Left a voicemail")
  end
end
