# frozen_string_literal: true

RSpec.describe Vms::Transformers::FieldNormalizer do
  describe ".pascal_to_snake" do
    it "converts simple PascalCase" do
      expect(described_class.pascal_to_snake("FirstName")).to eq("first_name")
    end

    it "converts consecutive capitals" do
      expect(described_class.pascal_to_snake("PartyID")).to eq("party_id")
    end

    it "converts camelCase" do
      expect(described_class.pascal_to_snake("firstName")).to eq("first_name")
    end

    it "handles single word" do
      expect(described_class.pascal_to_snake("Active")).to eq("active")
    end
  end

  describe ".snake_to_pascal" do
    it "converts snake_case to PascalCase" do
      expect(described_class.snake_to_pascal("first_name")).to eq("FirstName")
    end
  end

  describe ".normalize_value" do
    it "parses ASP.NET date format to ISO 8601" do
      expect(described_class.normalize_value("/Date(1710460800000)/")).to eq("2024-03-15")
    end

    it "passes through non-date strings" do
      expect(described_class.normalize_value("Jane")).to eq("Jane")
    end

    it "passes through non-string values" do
      expect(described_class.normalize_value(42)).to eq(42)
      expect(described_class.normalize_value(true)).to eq(true)
      expect(described_class.normalize_value(nil)).to be_nil
    end
  end

  describe ".normalize_record" do
    it "converts PascalCase keys to snake_case" do
      record = { "FirstName" => "Jane", "LastName" => "Smith" }
      result = described_class.normalize_record(record)
      expect(result).to eq("first_name" => "Jane", "last_name" => "Smith")
    end

    it "applies FIELD_ALIASES for known special fields" do
      record = { "EncyptedPartyID" => "abc==" }
      result = described_class.normalize_record(record)
      expect(result).to eq("encrypted_party_id" => "abc==")
    end

    it "parses ASP.NET dates in values" do
      record = { "Inquired" => "/Date(1710460800000)/" }
      result = described_class.normalize_record(record)
      expect(result["inquired"]).to eq("2024-03-15")
    end

    it "handles all FIELD_ALIASES" do
      %w[EncryptedID InquiryID PartyID ProgramID CountyID].each do |key|
        record = { key => "val" }
        result = described_class.normalize_record(record)
        expect(result.keys.first).to match(/\A[a-z_]+\z/)
      end
    end
  end

  describe ".normalize_records" do
    it "normalizes a batch of records" do
      records = [
        { "FirstName" => "A" },
        { "FirstName" => "B" }
      ]
      result = described_class.normalize_records(records)
      expect(result.map { |r| r["first_name"] }).to eq(%w[A B])
    end
  end
end
