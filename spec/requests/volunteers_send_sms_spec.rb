# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer SMS send", type: :request do
  include_context "Mailchimp SMS enabled"

  let(:user) { create(:user) }
  let!(:volunteer) { create(:volunteer, phone: "2015550123") }
  let(:client) { instance_double(Mailchimp::TransactionalClient) }
  let(:result) { { "status" => "sent", "external_id" => "spec-sms-id", "to" => "+12015550123" } }

  before do
    login_as(user, scope: :user)
    allow(Mailchimp::TransactionalClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_sms).and_return(result)
  end

  def send_sms(message: "Reminder: session tomorrow", consent: "onetime")
    post send_sms_volunteer_path(volunteer), params: { message: message, consent: consent }
  end

  it "provides a working compose link from the Inquiry list" do
    get volunteers_path
    expect(response.body).to include(sms_volunteer_path(volunteer))
    get sms_volunteer_path(volunteer)
    expect(response.body).to include('name="message"', 'name="consent"', "Select consent")
  end

  it "records the send and displays email and SMS together in the volunteer history" do
    volunteer.communications.create!(communication_type: :email, subject: "Session details", body: "Email content", status: :sent)
    expect { send_sms }.to change { volunteer.communications.sms.count }.by(1)
    expect(response).to redirect_to(volunteer_path(volunteer))
    follow_redirect!
    history = Nokogiri::HTML(response.body).at_css("#communications").text
    expect(response.body).to include("SMS sent to Mailchimp")
    expect(history).to include("EMAIL", "Session details", "Email content", "SMS", "Reminder: session tomorrow", "spec-sms-id", user.full_name)
    expect(history).not_to include("delivered")
  end

  it "shows queued accurately" do
    result["status"] = "queued"
    send_sms
    expect(flash[:notice]).to eq("SMS queued by Mailchimp")
    expect(volunteer.communications.last).to be_queued
  end

  it "retains the message and consent after a provider rejection" do
    result.merge!("status" => "rejected", "reject_reason" => "unsub")
    send_sms
    expect(response).to have_http_status(:unprocessable_entity)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("textarea#message").text).to eq("Reminder: session tomorrow")
    expect(html.at_css("select#consent option[selected]")["value"]).to eq("onetime")
    expect(response.body).to include("rejected", "failed", "unsub")
    expect(flash[:notice]).to be_nil
  end

  it "reports disabled sending without recording or claiming success" do
    ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "false"
    expect { send_sms }.not_to change(Communication, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("SMS sending is not enabled")
    expect(flash[:notice]).to be_nil
  end

  it "does not infer consent from a phone number or contact preference" do
    volunteer.update!(preferred_contact_method: :sms)
    expect { send_sms(consent: "") }.not_to change(Communication, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Select the SMS consent")
  end

  it "displays validation errors on the compose page" do
    send_sms(message: " ")
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Message cannot be blank")
    send_sms(message: "x" * 321)
    expect(response.body).to include("Message is too long")
    volunteer.update!(phone: nil)
    send_sms
    expect(response.body).to include("Add a phone number")
    volunteer.update!(phone: "000")
    send_sms
    expect(response.body).to include("Enter a valid phone number")
    expect(client).not_to have_received(:send_sms)
  end

  it "requires staff sign-in" do
    logout(:user)
    expect { send_sms }.not_to change(Communication, :count)
    expect(response).to have_http_status(:redirect)
    expect(client).not_to have_received(:send_sms)
  end
end
