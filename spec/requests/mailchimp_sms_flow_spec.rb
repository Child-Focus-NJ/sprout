# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SMS request through Rails and Mandrill", type: :request do
  include_context "Mailchimp SMS enabled"

  it "keeps a server-side failure pending and warns before resending" do
    user = create(:user)
    volunteer = create(:volunteer, phone: "2015550123")
    login_as(user, scope: :user)
    response_double = instance_double(HTTParty::Response, success?: false, code: 502)
    expect(Mailchimp::TransactionalClient).to receive(:post).once.and_return(response_double)
    post send_sms_volunteer_path(volunteer), params: { message: "Session reminder", consent: "onetime" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(volunteer.communications.last).to have_attributes(status: "pending", sent_at: nil)
    expect(response.body).to include("Check Mailchimp activity before resending")
    expect(flash[:notice]).to be_nil
  end

  it "persists and displays a documented provider result" do
    user = create(:user)
    volunteer = create(:volunteer, phone: "2015550123")
    login_as(user, scope: :user)

    response_double = instance_double(
      HTTParty::Response,
      success?: true,
      body: JSON.generate([
        { "to" => "+12015550123", "from" => "+12015550100", "status" => "sent", "_id" => "spec-flow-id" }
      ])
    )
    expect(Mailchimp::TransactionalClient).to receive(:post).with(
      "/messages/send-sms",
      hash_including(body: a_string_including("Session reminder", "onetime", "+12015550123"))
    ).and_return(response_double)

    post send_sms_volunteer_path(volunteer), params: { message: "Session reminder", consent: "onetime" }
    expect(response).to redirect_to(volunteer_path(volunteer))
    expect(volunteer.communications.last).to have_attributes(status: "sent", external_id: "spec-flow-id", sms_consent: "onetime")
    follow_redirect!
    expect(response.body).to include("Session reminder", "spec-flow-id")
  end
end
