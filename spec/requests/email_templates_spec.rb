# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Email template composition", type: :request do
  include_context "Mailchimp email provider"
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, first_name: "Jane", email: "jane@example.com") }
  let!(:template) do
    CommunicationTemplate.create!(name: "Session follow-up", subject: "See you soon, {{first_name}}",
      body: "Hi {{first_name}}, thanks for coming.\n\n— {{organization_name}}",
      template_type: :email, funnel_stage: :inquiry, trigger_type: :manual, active: true)
  end

  before { login_as(user, scope: :user) }

  def picker_options(scope)
    response.parsed_body.css("#{scope} [data-email-template-picker] option").map(&:text)
  end

  it "only offers active email templates in the popup and on the full page" do
    template.dup.update!(name: "SMS only", template_type: :sms)
    template.dup.update!(name: "Inactive draft", active: false)

    get volunteer_path(volunteer)
    expect(picker_options("#message-dialog-email")).to eq([ "Custom email", "Session follow-up" ])
    get email_volunteer_path(volunteer)
    expect(picker_options("#email-compose")).to eq([ "Custom email", "Session follow-up" ])
  end

  it "fills in the subject and message for this volunteer without recording or sending an email" do
    expect do
      get email_template_volunteer_path(volunteer), params: { template_id: template.id }
    end.not_to change(Communication, :count)
    expect(response.parsed_body).to eq(
      "subject" => "See you soon, Jane", "body" => "Hi Jane, thanks for coming.\n\n— Child Focus NJ"
    )
    expect(email_client).not_to have_received(:send_email)
  end

  it "explains when there are no email templates and links to creating one" do
    template.update!(active: false)
    get volunteer_path(volunteer)

    panel = response.parsed_body.at_css("#message-dialog-email")
    expect(panel.at_css("[data-email-template-picker]")["disabled"]).to be_present
    expect(panel.text).to include("No active email templates yet.")
    expect(panel.at_css("a[href='#{new_admin_communication_template_path}']").text).to eq("Create email template")
  end

  it "requires sign-in to read a filled-in template" do
    logout(:user)
    get email_template_volunteer_path(volunteer), params: { template_id: template.id }
    expect(response).to redirect_to(login_path)
  end

  it "sends the edited draft and records the template it started from" do
    post send_email_volunteer_path(volunteer), params: {
      template_id: template.id, subject: "See you soon, Jane", message: "Hi Jane, see you Thursday!"
    }
    expect(response).to redirect_to(volunteer_path(volunteer))
    expect(volunteer.communications.last).to have_attributes(
      subject: "See you soon, Jane", body: "Hi Jane, see you Thursday!", communication_template: template,
      sent_by_user: user, status: "sent"
    )
    expect(email_client).to have_received(:send_email)
      .with(to: "jane@example.com", subject: "See you soon, Jane", text_body: "Hi Jane, see you Thursday!")
  end

  [ :inactive, :sms, :deleted ].each do |invalid_kind|
    it "rejects a #{invalid_kind} template when filling in and when sending, and keeps the draft" do
      id = template.id
      case invalid_kind
      when :inactive then template.update!(active: false)
      when :sms then template.update!(template_type: :sms)
      when :deleted then template.destroy!
      end
      get email_template_volunteer_path(volunteer), params: { template_id: id }
      expect(response).to have_http_status(:unprocessable_entity)

      expect do
        post send_email_volunteer_path(volunteer), params: { template_id: id, subject: "Kept subject", message: "Kept draft" }
      end.not_to change(Communication, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.at_css("input#subject")["value"]).to eq("Kept subject")
      expect(response.parsed_body.at_css("textarea#message").text.strip).to eq("Kept draft")
      expect(email_client).not_to have_received(:send_email)
    end
  end

  it "keeps the chosen template selected when a send fails" do
    allow(email_client).to receive(:send_email).and_return(
      { "status" => "rejected", "external_id" => "id", "to" => volunteer.email, "reject_reason" => "unsub" }
    )
    post send_email_volunteer_path(volunteer), params: { template_id: template.id, subject: "Edited", message: "Edited draft" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.at_css("#email-compose [data-email-template-picker] option[selected]")["value"]).to eq(template.id.to_s)
    expect(volunteer.communications.last).to have_attributes(communication_template: template, status: "failed")
  end

  context "when email sending is turned off" do
    around do |example|
      previous = ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"]
      ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "false"
      example.run
    ensure
      ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = previous
    end

    it "says so in the popup and turns off its Send button" do
      get volunteer_path(volunteer)

      panel = response.parsed_body.at_css("#message-dialog-email")
      expect(panel.at_css(".message-dialog__notice").text).to eq(Email::DISABLED_MESSAGE)
      send_button = panel.at_css("button[type='submit']")
      expect(send_button["disabled"]).to be_present
      expect(send_button["data-send-disabled"]).to be_present
    end
  end
end
