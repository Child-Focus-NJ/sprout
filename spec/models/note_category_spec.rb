# frozen_string_literal: true

require "rails_helper"

RSpec.describe NoteCategory, type: :model do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer) }

  it "requires a unique name" do
    create(:note_category, name: "Phone call")

    expect(build(:note_category, name: "")).not_to be_valid
    expect(build(:note_category, name: "Phone call")).not_to be_valid
  end

  describe ".default" do
    it "finds or creates the Note category" do
      expect { described_class.default }.to change(described_class, :count).by(1)
      expect(described_class.default).to have_attributes(key: "note", name: "Note")
      expect { described_class.default }.not_to change(described_class, :count)
    end
  end

  describe "#updates_records?" do
    it "is true only for session outcomes and Deactivated" do
      updating = %w[attended_info_session no_show rescheduled cancelled deactivated]
      updating.each { |key| expect(described_class.new(key: key).updates_records?).to be(true), key }

      expect(described_class.new(key: "note").updates_records?).to be false
      expect(described_class.new(key: nil).updates_records?).to be false
    end
  end

  describe ".plain" do
    it "includes Note and admin-added categories but not ones that update records" do
      note = described_class.default
      custom = create(:note_category, name: "Phone call")
      described_class.create!(key: "no_show", name: "No-show")

      expect(described_class.plain).to contain_exactly(note, custom)
    end
  end

  describe "#destroy" do
    it "can't remove a built-in category, even after it's renamed" do
      no_show = described_class.create!(key: "no_show", name: "Missed it")

      expect(no_show.destroy).to be false
      expect(no_show.errors.full_messages).to include("Missed it is built in and can't be removed")
      expect(described_class.exists?(no_show.id)).to be true
    end

    it "moves a removed category's notes to Note" do
      custom = create(:note_category, name: "Phone call")
      note = volunteer.add_staff_note!(content: "Called", user: user, note_category: custom)

      custom.destroy!

      expect(note.reload.note_category).to eq(described_class.default)
      expect(note.content).to eq("Called")
    end
  end
end
