# frozen_string_literal: true

require "rails_helper"

RSpec.describe Note, type: :model do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer) }

  it "is a plain Note when no category is given" do
    note = volunteer.add_staff_note!(content: "Left voicemail", user: user)

    expect(note.note_category).to eq(NoteCategory.default)
  end

  describe "#editable_by?" do
    it "lets only the author edit a note they wrote" do
      note = volunteer.add_staff_note!(content: "Left voicemail", user: user)

      expect(note.editable_by?(user)).to be true
      expect(note.editable_by?(create(:user))).to be false
      expect(note.editable_by?(nil)).to be false
    end

    it "keeps notes logged automatically as recorded" do
      note = volunteer.add_staff_note!(content: "Reminder email sent", user: user, note_type: :communication)

      expect(note.editable_by?(user)).to be false
    end
  end
end
