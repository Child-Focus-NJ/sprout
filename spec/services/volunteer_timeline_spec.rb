# frozen_string_literal: true

require "rails_helper"

RSpec.describe VolunteerTimeline do
  let(:user) { create(:user, first_name: "Pat", last_name: "Admin") }
  let(:volunteer) { create(:volunteer) }

  describe ".entries_for" do
    it "merges notes, communications, and info session registrations" do
      session = create(:information_session, name: "Spring Orientation")
      travel_to(Time.zone.parse("2024-06-01 10:00")) do
        volunteer.add_staff_note!(content: "Called volunteer", user: user, note_type: :general)
      end
      volunteer.reload

      travel_to(Time.zone.parse("2024-06-03 12:00")) do
        volunteer.communications.create!(
          communication_type: :sms,
          body: "See you Saturday",
          sent_at: Time.current,
          sent_by_user: user,
          status: :delivered
        )
      end

      travel_to(Time.zone.parse("2024-06-02 09:00")) do
        SessionRegistration.create!(
          volunteer: volunteer,
          information_session: session,
          status: :registered
        )
      end

      entries = described_class.entries_for(volunteer.reload, filter: VolunteerTimeline::FILTER_ALL)
      kinds = entries.map { |e| e[:kind] }
      expect(kinds).to include(:note, :sms, :info_session)

      texts = entries.map { |e| e[:text] }
      expect(texts).to include("Called volunteer", "See you Saturday", "Info session: Spring Orientation")
    end

    it "returns newest-first ordering" do
      travel_to(Time.zone.parse("2024-01-10 10:00")) do
        volunteer.add_staff_note!(content: "Oldest", user: user, note_type: :general)
      end
      travel_to(Time.zone.parse("2024-01-12 10:00")) do
        volunteer.add_staff_note!(content: "Newest", user: user, note_type: :general)
      end

      entries = described_class.entries_for(volunteer.reload, filter: VolunteerTimeline::FILTER_ALL)
      expect(entries.first[:text]).to eq("Newest")
      expect(entries.last[:text]).to eq("Oldest")
    end

    it "includes author byline for notes" do
      volunteer.add_staff_note!(content: "Follow up next week", user: user, note_type: :general)

      entry = described_class.entries_for(volunteer.reload, filter: VolunteerTimeline::FILTER_ALL).find { |e| e[:kind] == :note }
      expect(entry[:byline]).to eq("Pat Admin")
    end

    it "when filter is notes, excludes non-note entries" do
      volunteer.add_staff_note!(content: "Manual note", user: user, note_type: :general)
      # Omit sent_by_user so Communication does not auto-create a second timeline note.
      volunteer.communications.create!(
        communication_type: :email,
        body: "Reminder",
        sent_at: Time.current,
        sent_by_user: nil,
        status: :sent
      )
      session = create(:information_session)
      SessionRegistration.create!(volunteer: volunteer, information_session: session, status: :registered)

      entries = described_class.entries_for(volunteer.reload, filter: VolunteerTimeline::FILTER_NOTES)
      expect(entries.map { |e| e[:kind] }).to eq([ :note ])
      expect(entries.first[:text]).to eq("Manual note")
    end

    it "treats blank filter like all activity" do
      volunteer.add_staff_note!(content: "Only a note", user: user, note_type: :general)
      volunteer.communications.create!(
        communication_type: :sms,
        body: "Hi",
        sent_at: Time.current,
        sent_by_user: user,
        status: :delivered
      )

      all_blank = described_class.entries_for(volunteer.reload, filter: "")
      all_explicit = described_class.entries_for(volunteer.reload, filter: VolunteerTimeline::FILTER_ALL)
      expect(all_blank.map { |e| e[:kind] }.sort).to eq(all_explicit.map { |e| e[:kind] }.sort)
    end
  end
end
