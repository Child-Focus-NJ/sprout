# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer email sending", type: :request do
  include_context "Mailchimp email provider"
  let(:user) { create(:user) }
  let!(:volunteer) { create(:volunteer) }

  before { login_as(user, scope: :user) }

  def send_email(subject: "Session details", message: "Hello <script>alert(1)</script>")
    post send_email_volunteer_path(volunteer), params: { subject: subject, message: message }
  end

  it "opens compose from the list and profile" do
    get volunteers_path
    expect(response.body).to include(email_volunteer_path(volunteer))
    get volunteer_path(volunteer)
    expect(response.body).to include(email_volunteer_path(volunteer))
    get email_volunteer_path(volunteer)
    expect(response.body).to include('name="subject"', 'name="message"', volunteer.email)
  end

  it "sends and displays escaped content, recipient, sender and provider ID" do
    expect { send_email }.to change(Communication.email, :count).by(1)
    expect(response).to redirect_to(volunteer_path(volunteer))
    follow_redirect!
    expect(response.body).to include("Email sent to Mailchimp", "Session details", "spec-email-id", user.full_name, volunteer.email)
    expect(response.body).to include("&lt;script&gt;")
    expect(response.body).not_to include("<script>alert(1)</script>")
  end

  context "when queued" do
    let(:email_status) { "queued" }

    it "reports queued and leaves sent time unset" do
      send_email
      expect(flash[:notice]).to eq("Email queued by Mailchimp")
      expect(volunteer.communications.last.sent_at).to be_nil
    end
  end

  it "preserves the draft when Mailchimp rejects it" do
    allow(email_client).to receive(:send_email).and_return({ "status" => "rejected", "external_id" => "id", "to" => volunteer.email, "reject_reason" => "unsub" })
    send_email
    expect(response).to have_http_status(:unprocessable_entity)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("input#subject")["value"]).to eq("Session details")
    expect(html.at_css("textarea#message").text.delete_prefix("\n")).to eq("Hello <script>alert(1)</script>")
    expect(response.body).to include("failed", "unsub")
  end

  it "shows validation and disabled-configuration errors without sending" do
    send_email(subject: " ")
    expect(response.body).to include("Subject cannot be blank")
    send_email(message: " ")
    expect(response.body).to include("Message cannot be blank")
    ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "false"
    send_email
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Email sending is not enabled")
    expect(volunteer.communications).to be_empty
    expect(email_client).not_to have_received(:send_email)
  end

  it "requires sign-in" do
    logout(:user)
    expect { send_email }.not_to change(Communication, :count)
    expect(response).to redirect_to(login_path)
    expect(email_client).not_to have_received(:send_email)
  end

  it "blocks application sending until an admin provides the link" do
    SystemSetting.set("application_url", "")
    post send_application_volunteer_path(volunteer)
    expect(flash[:alert]).to include("Admin settings")
    expect(volunteer.reload.application_sent_at).to be_nil
    expect(email_client).not_to have_received(:send_email)
  end

  it "sends the application link saved through the admin UI and prevents duplicate sends" do
    login_as(create(:user, role: :admin), scope: :user)
    patch admin_settings_path, params: { application_url: "https://example.org/latest-application" }
    login_as(user, scope: :user)
    post send_application_volunteer_path(volunteer)
    expect(flash[:notice]).to eq("Application email sent to Mailchimp")
    expect(volunteer.communications.last.body).to include("https://example.org/latest-application")
    expect(volunteer.reload.application_sent_at).to be_present
    post send_application_volunteer_path(volunteer)
    expect(flash[:alert]).to include("already sent")
    expect(email_client).to have_received(:send_email).once
  end
end
