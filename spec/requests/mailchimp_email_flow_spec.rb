# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Email request through Rails and Mandrill", type: :request do
  include_context "Mailchimp email enabled"

  let(:volunteer) { create(:volunteer) }

  before { login_as(create(:user), scope: :user) }

  it "sends through every application layer and displays the provider ID" do
    response_double = instance_double(
      HTTParty::Response,
      success?: true,
      body: JSON.generate([ { "email" => volunteer.email, "status" => "sent", "_id" => "flow-id" } ])
    )
    expect(Mailchimp::TransactionalClient).to receive(:post).with(
      "/messages/send",
      hash_including(body: a_string_including("Details", "Your message", volunteer.email))
    ).and_return(response_double)

    post send_email_volunteer_path(volunteer), params: { subject: "Details", message: "Your message" }
    expect(response).to redirect_to(volunteer_path(volunteer))
    expect(volunteer.communications.last).to have_attributes(status: "sent", external_id: "flow-id")
    follow_redirect!
    expect(response.body).to include("flow-id", "Your message", "Email sent to Mailchimp")
  end

  it "preserves the draft and records uncertainty when the provider times out" do
    allow(Mailchimp::TransactionalClient).to receive(:post).and_raise(Net::ReadTimeout)

    post send_email_volunteer_path(volunteer), params: { subject: "Details", message: "Your message" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("before resending", "Your message")
    expect(volunteer.communications.last).to have_attributes(status: "pending", sent_at: nil)
  end
end
