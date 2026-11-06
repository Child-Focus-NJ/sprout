# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferralSource, type: :model do
  let!(:website) { create(:referral_source, name: "Website") }
  let!(:other) { create(:referral_source, name: "Other") }
  let!(:idealist) { create(:referral_source, name: "Idealist") }
  let!(:flyer) { create(:referral_source, name: "Flyer", active: false) }

  describe ".menu_order" do
    it "lists the sources A to Z with Other last" do
      expect(described_class.menu_order.pluck(:name)).to eq([ "Flyer", "Idealist", "Website", "Other" ])
    end
  end

  describe ".choices_for" do
    it "offers only the active sources" do
      expect(described_class.choices_for(nil)).to eq([ idealist, website, other ])
    end

    it "keeps a retired source that is already picked, so saving doesn't clear it" do
      expect(described_class.choices_for(flyer.id)).to eq([ flyer, idealist, website, other ])
    end
  end
end
