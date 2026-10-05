# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMetrics do
  let(:today) { Date.new(2026, 9, 24) }

  subject(:metrics) { described_class.new(today: today) }

  describe "sign-in activity" do
    it "counts all sign-ins and the ones from this month" do
      user = create(:user)
      create(:volunteer)
      SignInLog.create!(user: user, created_at: Time.zone.local(2026, 9, 1, 8))
      SignInLog.create!(user: user, created_at: Time.zone.local(2026, 9, 24, 20))
      SignInLog.create!(user: user, created_at: Time.zone.local(2026, 8, 31, 23))

      expect(metrics.total_sign_ins).to eq(3)
      expect(metrics.sign_ins_this_month).to eq(2)
    end

    it "lists the most recent sign-ins first, up to the limit" do
      user = create(:user)
      older = SignInLog.create!(user: user, created_at: 2.days.ago)
      newer = SignInLog.create!(user: user, created_at: 1.day.ago)

      recent = metrics.recent_sign_ins(limit: 1)

      expect(recent).to eq([ newer ])
      expect(recent).not_to include(older)
    end
  end

  describe "data volume" do
    it "counts volunteers, information sessions, and notes" do
      create_list(:volunteer, 2)
      create(:information_session)
      volunteer = create(:volunteer)
      volunteer.notes.create!(user: create(:user), content: "Note")

      expect(metrics.total_volunteers).to eq(3)
      expect(metrics.total_information_sessions).to eq(1)
      expect(metrics.total_notes).to eq(1)
    end
  end

  describe "communication volume" do
    it "counts communications and breaks them down by type" do
      volunteer = create(:volunteer)
      volunteer.communications.create!(communication_type: :email, body: "Hi", sent_at: Time.current)
      volunteer.communications.create!(communication_type: :email, body: "Hi again", sent_at: Time.current)
      volunteer.communications.create!(communication_type: :sms, body: "Text", sent_at: Time.current)

      expect(metrics.total_communications).to eq(3)
      expect(metrics.communications_by_type).to eq("email" => 2, "sms" => 1)
    end

    it "includes a type with zero communications" do
      volunteer = create(:volunteer)
      volunteer.communications.create!(communication_type: :email, body: "Hi", sent_at: Time.current)

      expect(metrics.communications_by_type).to eq("email" => 1, "sms" => 0)
    end
  end
end
