# frozen_string_literal: true

require "rails_helper"

RSpec.describe Communication, type: :model do
  let(:volunteer) { create(:volunteer) }
  let(:user) { create(:user) }

  describe "SMS locally recorded (sent_at on create)" do
    it "promotes pending SMS with sent_at to delivered" do
      comm = volunteer.communications.create!(
        communication_type: :sms,
        body: "Hello",
        sent_at: Time.current,
        sent_by_user: user
      )

      comm.reload
      expect(comm.delivered?).to be true
    end

    it "adds a staff note when sent_by_user is present" do
      expect do
        volunteer.communications.create!(
          communication_type: :sms,
          body: "Hello",
          sent_at: Time.current,
          sent_by_user: user
        )
      end.to change { volunteer.notes.where(note_type: :communication).count }.by(1)
    end

    it "does not add a staff note when sent_by_user is absent" do
      expect do
        volunteer.communications.create!(
          communication_type: :sms,
          body: "Hello",
          sent_at: Time.current,
          sent_by_user: nil
        )
      end.not_to change { volunteer.notes.count }
    end
  end

  describe "SMS Mailchimp-style (sent_at set after create)" do
    it "logs a staff note when sent_at is first set on update" do
      comm = volunteer.communications.create!(
        communication_type: :sms,
        body: "Later",
        sent_by_user: user,
        status: :pending,
        sent_at: nil
      )

      expect do
        comm.update!(sent_at: Time.zone.parse("2026-04-08 14:00"), status: :delivered)
      end.to change { volunteer.notes.where(note_type: :communication).count }.by(1)
    end
  end
end
