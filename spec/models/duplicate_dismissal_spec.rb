require "rails_helper"

RSpec.describe DuplicateDismissal do
  let(:staff) { create(:user) }
  let!(:first) { create(:volunteer) }
  let!(:second) { create(:volunteer) }

  describe ".dismiss!" do
    it "stores the pair lowest id first, whichever order it's given in" do
      dismissal = described_class.dismiss!(second, first, user: staff)

      expect([ dismissal.volunteer, dismissal.other_volunteer, dismissal.user ]).to eq([ first, second, staff ])
    end

    it "keeps one row and the first staff member when the pair is dismissed again" do
      original = described_class.dismiss!(first, second, user: staff)

      expect(described_class.dismiss!(second, first, user: create(:user))).to eq(original)
      expect(described_class.count).to eq(1)
      expect(original.reload.user).to eq(staff)
    end
  end

  it "rejects a pair stored highest id first or the same volunteer twice" do
    expect(described_class.new(volunteer: second, other_volunteer: first)).not_to be_valid
    expect(described_class.new(volunteer: first, other_volunteer: first)).not_to be_valid
  end

  it "goes away when either volunteer is deleted" do
    described_class.dismiss!(first, second, user: staff)

    second.destroy!

    expect(described_class.count).to eq(0)
  end
end
