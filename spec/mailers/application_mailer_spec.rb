require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  around do |example|
    keys = %w[MANDRILL_FROM_EMAIL MAILCHIMP_EMAIL_FROM]
    previous = keys.to_h { |key| [ key, ENV[key] ] }
    keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "uses the configured verified sender for reminder emails" do
    ENV["MANDRILL_FROM_EMAIL"] = "sprout@example.org"
    ENV["MAILCHIMP_EMAIL_FROM"] = "legacy@example.org"
    communication = Communication.new(volunteer: build(:volunteer), subject: "Test", body: "Reminder")
    expect(TemplateMailer.follow_up(communication).from).to eq([ "sprout@example.org" ])
  end

  it "uses the legacy sender setting when no Mandrill sender is set" do
    ENV["MAILCHIMP_EMAIL_FROM"] = "legacy@example.org"
    expect(InquiryMailer.confirmation("tester@example.org").from).to eq([ "legacy@example.org" ])
  end

  it "preserves the existing default when no sender is configured" do
    expect(InquiryMailer.confirmation("tester@example.org").from).to eq([ "noreply@childfocusnj.org" ])
  end
end
