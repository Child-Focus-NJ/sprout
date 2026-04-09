# frozen_string_literal: true

RSpec.describe Vms::Transformers::KendoResponse do
  describe ".parse" do
    it "parses PascalCase keys (Data/Total)" do
      json = '{"Data": [{"Name": "A"}], "Total": 1}'
      result = described_class.parse(json)
      expect(result["data"]).to eq([ { "Name" => "A" } ])
      expect(result["total"]).to eq(1)
    end

    it "parses lowercase keys (data/total)" do
      json = '{"data": [{"Name": "B"}], "total": 2}'
      result = described_class.parse(json)
      expect(result["data"]).to eq([ { "Name" => "B" } ])
      expect(result["total"]).to eq(2)
    end

    it "returns empty array when no data key" do
      json = '{"Total": 0}'
      result = described_class.parse(json)
      expect(result["data"]).to eq([])
      expect(result["total"]).to eq(0)
    end

    it "defaults total to data length when missing" do
      json = '{"data": [{"a": 1}, {"a": 2}]}'
      result = described_class.parse(json)
      expect(result["total"]).to eq(2)
    end

    it "raises on invalid JSON" do
      expect { described_class.parse("not json") }.to raise_error(JSON::ParserError)
    end
  end
end
