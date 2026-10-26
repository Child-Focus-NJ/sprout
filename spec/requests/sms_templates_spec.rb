# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SMS template composition", type: :request do
  include_context "Mailchimp SMS enabled"
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, first_name: "Jane", phone: "2015550123") }
  let!(:template) do
    CommunicationTemplate.create!(name: "Session reminder", body: "Hi {{first_name}}, your session is tomorrow.",
      template_type: :sms, funnel_stage: :inquiry, trigger_type: :manual, active: true)
  end
  let(:client) { instance_double(Mailchimp::TransactionalClient) }

  before do
    login_as(user, scope: :user)
    allow(Mailchimp::TransactionalClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_sms) do |to:, **|
      { "status" => "sent", "external_id" => "template-#{to}", "to" => to }
    end
  end

  it "only lists active SMS templates, even when email templates and inactive drafts exist" do
    template.dup.update!(name: "Email only", template_type: :email)
    template.dup.update!(name: "Inactive draft", active: false)
    get sms_volunteer_path(volunteer)
    options = response.parsed_body.css("[data-sms-template-picker] option").map(&:text)
    expect(options).to eq([ "Custom message", "Session reminder" ])
  end

  it "personalizes the selected template without recording or sending a message" do
    expect do
      get sms_template_volunteer_path(volunteer), params: { template_id: template.id }
    end.not_to change(Communication, :count)
    expect(response.parsed_body).to eq("body" => "Hi Jane, your session is tomorrow.")
    expect(client).not_to have_received(:send_sms)
  end

  it "requires staff authentication to read personalized templates" do
    logout(:user)
    get sms_template_volunteer_path(volunteer), params: { template_id: template.id }
    expect(response).to redirect_to(login_path)
  end

  it "sends the edited draft and records its template, recipient and staff sender" do
    post send_sms_volunteer_path(volunteer), params: {
      template_id: template.id, message: "Hi Jane, your session moved to Friday.", consent: "onetime"
    }
    expect(response).to redirect_to(volunteer_path(volunteer))
    expect(volunteer.communications.last).to have_attributes(
      body: "Hi Jane, your session moved to Friday.", communication_template: template, sent_by_user: user, status: "sent"
    )
    expect(client).to have_received(:send_sms).with(to: "+12015550123", message: "Hi Jane, your session moved to Friday.", consent: "onetime")
  end

  [ :inactive, :email, :deleted ].each do |invalid_kind|
    it "rejects a #{invalid_kind} template at preview and send time" do
      id = template.id
      case invalid_kind
      when :inactive then template.update!(active: false)
      when :email then template.update!(template_type: :email)
      when :deleted then template.destroy!
      end
      get sms_template_volunteer_path(volunteer), params: { template_id: id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect do
        post send_sms_volunteer_path(volunteer), params: { template_id: id, message: "Kept draft", consent: "onetime" }
      end.not_to change(Communication, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.at_css("#message").text).to eq("Kept draft")
      expect(client).not_to have_received(:send_sms)
    end
  end

  it "keeps the edited draft, template and consent after a definite provider failure" do
    allow(client).to receive(:send_sms).and_raise(Mailchimp::TransactionalClient::ApiError)
    post send_sms_volunteer_path(volunteer), params: { template_id: template.id, message: "Edited draft", consent: "onetime" }
    expect(response.parsed_body.at_css("#message").text).to eq("Edited draft")
    expect(response.parsed_body.at_css("[data-sms-template-picker] option[selected]")["value"]).to eq(template.id.to_s)
    expect(volunteer.communications.last).to have_attributes(communication_template: template, status: "failed")
  end

  it "personalizes an edited bulk template for each recipient" do
    other = create(:volunteer, first_name: "Jack", phone: "2015550124")
    post bulk_send_sms_volunteers_path, params: {
      volunteer_ids: [ volunteer.id, other.id ], template_id: template.id,
      message: "Hi {{first_name}}, see you Friday!", consent: "onetime"
    }
    expect(flash[:notice]).to eq("SMS sent to 2 volunteers.")
    expect(volunteer.communications.last.body).to eq("Hi Jane, see you Friday!")
    expect(other.communications.last.body).to eq("Hi Jack, see you Friday!")
    expect(other.communications.last.communication_template).to eq(template)
  end

  it "checks the personalized length and still reports other successful bulk sends" do
    long_name = create(:volunteer, first_name: "X" * 320, phone: "2015550124")
    post bulk_send_sms_volunteers_path, params: {
      volunteer_ids: [ volunteer.id, long_name.id ], template_id: template.id,
      message: "Hi {{first_name}}", consent: "onetime"
    }
    expect(flash[:notice]).to eq("SMS sent to 1 volunteer. 1 couldn't be sent.")
    expect(volunteer.communications.last).to be_sent
    expect(long_name.communications).to be_empty
    expect(client).to have_received(:send_sms).once
  end
end
