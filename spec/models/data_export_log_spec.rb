# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExportLog, type: :model do
  it "defaults to a started, manual log" do
    log = DataExportLog.create!

    expect(log.trigger).to eq("manual")
    expect(log.status).to eq("started")
  end

  it "allows a nil user (for scheduled runs)" do
    expect(DataExportLog.new(user: nil)).to be_valid
  end

  it "nullifies user_id when the user is deleted, keeping the log" do
    user = create(:user)
    log = DataExportLog.create!(user: user)

    user.destroy

    expect(log.reload.user_id).to be_nil
  end

  it "orders most recent first" do
    older = DataExportLog.create!
    newer = DataExportLog.create!
    older.update_column(:created_at, 2.days.ago)

    expect(DataExportLog.recent.first).to eq(newer)
  end
end
