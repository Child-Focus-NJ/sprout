# frozen_string_literal: true

require "rails_helper"

# Long sent/failed message entries used to dump the whole body and error into the
# Send Email page, the Send SMS page, and the profile timeline. Each surface now
# renders a one-line preview (body + error) with the delivery status and a
# "Show more" control that expands it.
RSpec.describe "Collapsed message history", type: :request do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer) }
  let(:long_body) do
    "This is a long message body that should not be shown in full in the message history of this volunteer."
  end
  let(:error_message) { "The provider rejected this message: unsubscribed recipient." }

  before { login_as(user, scope: :user) }

  it "collapses previous emails on the Send Email page behind a Show more control" do
    volunteer.communications.create!(communication_type: :email, subject: "Session details",
                                     body: long_body, status: :failed, error_message: error_message)

    get email_volunteer_path(volunteer)

    entry = response.parsed_body.at_css("#email-history .communication-entry")
    expect(entry.at_css(".delivery-status").text.strip).to eq("failed")
    preview = entry.at_css(".collapsible-message__preview")
    expect(preview.text).to include(long_body, error_message)
    expect(preview["id"]).to eq("comm-body-#{volunteer.communications.first.id}")
    toggle = entry.at_css("button.collapsible-message__toggle")
    expect(toggle.text).to eq("Show more")
    expect(toggle["aria-expanded"]).to eq("false")
    expect(toggle["aria-controls"]).to eq("comm-body-#{volunteer.communications.first.id}")
  end

  it "collapses previous messages on the Send SMS page behind a Show more control" do
    volunteer.communications.create!(communication_type: :sms, body: long_body,
                                     status: :sent, sent_at: Time.current)

    get sms_volunteer_path(volunteer)

    entry = response.parsed_body.at_css("#sms-recipient .communication-entry")
    expect(entry.at_css(".delivery-status").text.strip).to eq("sent")
    expect(entry.at_css(".collapsible-message__preview").text).to include(long_body)
    toggle = entry.at_css("button.collapsible-message__toggle")
    expect(toggle.text).to eq("Show more")
    expect(toggle["aria-expanded"]).to eq("false")
  end

  it "collapses failed email and SMS entries on the profile timeline" do
    volunteer.communications.create!(communication_type: :sms, body: long_body,
                                     status: :failed, error_message: error_message, sent_at: Time.current)
    volunteer.communications.create!(communication_type: :email, subject: "Session details",
                                     body: long_body, status: :sent)

    get volunteer_path(volunteer)

    sms_entry = response.parsed_body.at_css(".timeline .sms-entry")
    expect(sms_entry.at_css(".delivery-status").text.strip).to eq("failed")
    expect(sms_entry.at_css(".collapsible-message__preview").text).to include(long_body, error_message)
    sms_toggle = sms_entry.at_css("button.collapsible-message__toggle")
    expect(sms_toggle.text).to eq("Show more")
    expect(sms_toggle["aria-expanded"]).to eq("false")

    email_entry = response.parsed_body.at_css(".timeline .email-entry")
    expect(email_entry.at_css(".collapsible-message__preview").text).to include(long_body)
    expect(email_entry.at_css("button.collapsible-message__toggle").text).to eq("Show more")
  end

  it "keeps short messages fully visible with no Show more control" do
    volunteer.communications.create!(communication_type: :email, subject: "Short",
                                     body: "Short note", status: :sent)

    get email_volunteer_path(volunteer)

    entry = response.parsed_body.at_css("#email-history .communication-entry")
    expect(entry.at_css(".collapsible-message__preview").text).to include("Short note")
    expect(entry.at_css("button.collapsible-message__toggle")).to be_nil
  end
end
