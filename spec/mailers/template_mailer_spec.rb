require "rails_helper"

RSpec.describe TemplateMailer, type: :mailer do
  describe "#follow_up" do
    it "sends the communication's subject and body to the volunteer's email" do
      volunteer = create(:volunteer, email: "jane@childfocusnj.org")
      communication = Communication.create!(
        volunteer: volunteer,
        communication_type: :email,
        subject: "Still there?",
        body: "Just checking in.",
        status: :pending
      )

      mail = TemplateMailer.follow_up(communication)

      expect(mail.to).to include("jane@childfocusnj.org")
      expect(mail.subject).to eq("Still there?")
      expect(mail.body.encoded).to include("Just checking in.")
    end

    it "falls back to a default subject when the communication has none" do
      volunteer = create(:volunteer, email: "jane@childfocusnj.org")
      communication = Communication.create!(
        volunteer: volunteer,
        communication_type: :email,
        subject: nil,
        body: "Just checking in.",
        status: :pending
      )

      mail = TemplateMailer.follow_up(communication)

      expect(mail.subject).to eq("A note from Child Focus NJ")
    end
  end
end
