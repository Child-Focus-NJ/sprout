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

    it "counts the distinct users who have signed in, not the number of sign-ins" do
      frequent_user = create(:user)
      occasional_user = create(:user)
      SignInLog.create!(user: frequent_user)
      SignInLog.create!(user: frequent_user)
      SignInLog.create!(user: occasional_user)

      expect(metrics.unique_sign_in_users).to eq(2)
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

    it "lists the most recent communications first, up to the limit" do
      volunteer = create(:volunteer)
      older = volunteer.communications.create!(communication_type: :email, body: "Old", sent_at: 2.days.ago, created_at: 2.days.ago)
      newer = volunteer.communications.create!(communication_type: :sms, body: "New", sent_at: 1.day.ago, created_at: 1.day.ago)

      recent = metrics.recent_communications(limit: 1)

      expect(recent).to eq([ newer ])
      expect(recent).not_to include(older)
    end
  end

  describe "employees" do
    it "counts active employees and breaks them down by role" do
      create(:user, role: :admin)
      create(:user, role: :user)
      create(:user, role: :user)
      create(:user, :inactive, role: :admin)

      expect(metrics.total_active_employees).to eq(3)
      expect(metrics.employees_by_role).to eq("admin" => 1, "user" => 2)
    end

    it "includes a role with no active employees" do
      create(:user, role: :user)

      expect(metrics.employees_by_role).to eq("admin" => 0, "user" => 1)
    end
  end
end
