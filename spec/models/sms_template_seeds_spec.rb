require "rails_helper"

RSpec.describe "SMS template seeds" do
  let(:seed_path) { Rails.root.join("db/seeds/sms_templates.rb") }

  it "provides a manual SMS starter without changing an email template with the same name" do
    email = CommunicationTemplate.create!(name: "General SMS follow-up", template_type: :email,
      body: "Email content", funnel_stage: :inquiry, active: true)

    load seed_path

    template = CommunicationTemplate.sms.find_by!(name: "General SMS follow-up")
    expect(template).to have_attributes(active: true, trigger_type: "manual")
    expect(template.render_body(Volunteer.new(first_name: "Jane"))).to start_with("Hi Jane,")
    expect(template.body.length).to be <= Sms::MailchimpOutbound::MAX_MESSAGE_LENGTH
    expect(email.reload.body).to eq("Email content")
    expect(Communication.count).to eq(0)
  end

  it "preserves staff edits and deactivation when seeds run again" do
    load seed_path
    template = CommunicationTemplate.sms.find_by!(name: "General SMS follow-up")
    template.update!(body: "Edited by staff", active: false)

    expect { load seed_path }.not_to change(CommunicationTemplate, :count)
    expect(template.reload).to have_attributes(body: "Edited by staff", active: false)
  end
end
