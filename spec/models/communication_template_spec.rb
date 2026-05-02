# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommunicationTemplate, type: :model do
  describe "validations" do
    it "is valid with all required fields" do
      template = CommunicationTemplate.new(
        name: "2-week follow-up",
        body: "Hi, just checking in.",
        funnel_stage: :inquiry,
        trigger_type: :interval,
        interval_weeks: 2
      )
      expect(template).to be_valid
    end

    it "is invalid without a name" do
      template = CommunicationTemplate.new(body: "Hi", funnel_stage: :inquiry)
      expect(template).not_to be_valid
      expect(template.errors[:name]).to be_present
    end

    it "is invalid without a body" do
      template = CommunicationTemplate.new(name: "Test", funnel_stage: :inquiry)
      expect(template).not_to be_valid
      expect(template.errors[:body]).to be_present
    end

    it "is invalid without a funnel_stage" do
      template = CommunicationTemplate.new(name: "Test", body: "Hi")
      expect(template).not_to be_valid
      expect(template.errors[:funnel_stage]).to be_present
    end
  end

  describe "US4: template types and trigger types" do
    it "supports email template type" do
      template = CommunicationTemplate.create!(name: "Email template", body: "Hi", funnel_stage: :inquiry, template_type: :email)
      expect(template).to be_email
    end

    it "supports sms template type" do
      template = CommunicationTemplate.create!(name: "SMS template", body: "Hi", funnel_stage: :inquiry, template_type: :sms)
      expect(template).to be_sms
    end

    it "supports interval trigger type" do
      template = CommunicationTemplate.create!(name: "Interval", body: "Hi", funnel_stage: :inquiry, trigger_type: :interval, interval_weeks: 2)
      expect(template).to be_interval
    end

    it "supports event trigger type" do
      template = CommunicationTemplate.create!(name: "Event", body: "Hi", funnel_stage: :inquiry, trigger_type: :event)
      expect(template).to be_event
    end

    it "supports manual trigger type" do
      template = CommunicationTemplate.create!(name: "Manual", body: "Hi", funnel_stage: :inquiry, trigger_type: :manual)
      expect(template).to be_manual
    end

    it "supports campaign trigger type" do
      template = CommunicationTemplate.create!(name: "Campaign", body: "Hi", funnel_stage: :inquiry, trigger_type: :campaign)
      expect(template).to be_campaign
    end
  end

  describe "US4: interval_weeks for configurable intervals" do
    [ 2, 4, 8, 12 ].each do |weeks|
      it "can be created with a #{weeks}-week interval" do
        template = CommunicationTemplate.create!(
          name: "#{weeks}-week follow-up",
          body: "Following up after #{weeks} weeks.",
          funnel_stage: :application_sent,
          trigger_type: :interval,
          interval_weeks: weeks
        )
        expect(template.interval_weeks).to eq(weeks)
      end
    end
  end

  describe "US4: funnel stages" do
    it "supports inquiry stage" do
      template = CommunicationTemplate.create!(name: "Inquiry", body: "Hi", funnel_stage: :inquiry)
      expect(template).to be_inquiry
    end

    it "supports application_eligible stage" do
      template = CommunicationTemplate.create!(name: "Eligible", body: "Hi", funnel_stage: :application_eligible)
      expect(template).to be_application_eligible
    end

    it "supports application_sent stage" do
      template = CommunicationTemplate.create!(name: "Sent", body: "Hi", funnel_stage: :application_sent)
      expect(template).to be_application_sent
    end
  end

  describe "US4: subject field for personalization" do
    it "stores a subject line" do
      template = CommunicationTemplate.create!(
        name: "Welcome",
        subject: "Welcome to Child Focus NJ",
        body: "Hi, thanks for your interest.",
        funnel_stage: :inquiry
      )
      expect(template.subject).to eq("Welcome to Child Focus NJ")
    end

    it "allows subject to be blank" do
      template = CommunicationTemplate.new(name: "No subject", body: "Hi", funnel_stage: :inquiry)
      expect(template).to be_valid
    end
  end

  describe "US4: active/inactive templates" do
    it "is active by default" do
      template = CommunicationTemplate.create!(name: "Active", body: "Hi", funnel_stage: :inquiry)
      expect(template.active).to be true
    end

    it "can be deactivated" do
      template = CommunicationTemplate.create!(name: "Inactive", body: "Hi", funnel_stage: :inquiry, active: false)
      expect(template.active).to be false
    end
  end

  describe "scopes" do
    before do
      CommunicationTemplate.delete_all
    end

    it ".active returns only active templates" do
      active = CommunicationTemplate.create!(name: "Active", body: "Hi", funnel_stage: :inquiry, active: true)
      inactive = CommunicationTemplate.create!(name: "Inactive", body: "Hi", funnel_stage: :inquiry, active: false)

      expect(CommunicationTemplate.active).to include(active)
      expect(CommunicationTemplate.active).not_to include(inactive)
    end

    it ".for_stage returns templates for a given funnel stage" do
      inquiry_template = CommunicationTemplate.create!(name: "Inquiry", body: "Hi", funnel_stage: :inquiry)
      sent_template = CommunicationTemplate.create!(name: "Sent", body: "Hi", funnel_stage: :application_sent)

      expect(CommunicationTemplate.for_stage(:inquiry)).to include(inquiry_template)
      expect(CommunicationTemplate.for_stage(:inquiry)).not_to include(sent_template)
    end

    it ".interval_triggers returns only interval-triggered templates" do
      interval = CommunicationTemplate.create!(name: "Interval", body: "Hi", funnel_stage: :inquiry, trigger_type: :interval)
      manual = CommunicationTemplate.create!(name: "Manual", body: "Hi", funnel_stage: :inquiry, trigger_type: :manual)

      expect(CommunicationTemplate.interval_triggers).to include(interval)
      expect(CommunicationTemplate.interval_triggers).not_to include(manual)
    end
  end

  describe "US3: AttendanceMailer.application_queued" do
    it "sends an application queued email to the volunteer" do
      mail = AttendanceMailer.application_queued("jane@childfocusnj.org")
      expect(mail.to).to include("jane@childfocusnj.org")
      expect(mail.subject).to eq("Application queued")
    end
  end
end
