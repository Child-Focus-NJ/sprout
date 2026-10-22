# frozen_string_literal: true

require "rails_helper"

RSpec.describe SignInLog, type: :model do
  it "records the signed-in user and their IP address" do
    user = create(:user)
    log = SignInLog.create!(user: user, ip_address: "127.0.0.1")

    expect(log.user).to eq(user)
    expect(log.ip_address).to eq("127.0.0.1")
  end

  it "requires a user" do
    log = SignInLog.new(ip_address: "127.0.0.1")

    expect(log).not_to be_valid
    expect(log.errors[:user]).to be_present
  end

  it "orders most recent first" do
    user = create(:user)
    older = SignInLog.create!(user: user)
    newer = SignInLog.create!(user: user)
    older.update_column(:created_at, 2.days.ago)

    expect(SignInLog.recent.first).to eq(newer)
  end
end
