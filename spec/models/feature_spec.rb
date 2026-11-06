# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feature, type: :model do
  it "requires a key" do
    expect(Feature.new(admin_only: true)).not_to be_valid
  end

  it "requires keys to be unique" do
    Feature.create!(key: "system_management", admin_only: true)

    expect(Feature.new(key: "system_management", admin_only: true)).not_to be_valid
  end

  describe ".admin_only?" do
    it "is true for a feature explicitly marked admin-only" do
      Feature.create!(key: "example", admin_only: true)

      expect(Feature.admin_only?("example")).to be true
    end

    it "is false for a feature explicitly opened up to everyone" do
      Feature.create!(key: "example", admin_only: false)

      expect(Feature.admin_only?("example")).to be false
    end

    it "fails closed for a key nobody registered, instead of silently allowing access" do
      expect(Feature.admin_only?("not_a_real_feature")).to be true
    end
  end
end
