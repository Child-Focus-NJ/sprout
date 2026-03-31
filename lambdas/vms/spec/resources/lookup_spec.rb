# frozen_string_literal: true

RSpec.describe Vms::Resources::Lookup do
  let(:http) { FakeHttpClient.new }
  let(:lookup) { described_class.new(http) }

  def stub_lookup_response(data)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, { "Data" => data, "Total" => data.length }.to_json)
    response
  end

  describe "#list" do
    it "returns 404 for unknown type" do
      result = lookup.list("Bogus")
      expect(result[:statusCode]).to eq(404)
      body = JSON.parse(result[:body])
      expect(body["error"]).to include("Unknown lookup type")
      expect(body["valid_types"]).to include("County")
    end

    it "routes County to /County controller" do
      http.stub_response(:post_json, "/County/_Index", stub_lookup_response([]))
      lookup.list("County")
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to start_with("/County/")
    end

    it "normalizes records to consistent shape" do
      data = [ { "CountyID" => 1, "EncryptedID" => "a==", "CountyName" => "Passaic", "Active" => true } ]
      http.stub_response(:post_json, "/County/_Index", stub_lookup_response(data))
      result = lookup.list("County")
      body = JSON.parse(result[:body])
      record = body["data"].first
      expect(record).to have_key("id")
      expect(record).to have_key("name")
      expect(record).to have_key("active")
    end

    it "accepts all 13 valid types" do
      Vms::Resources::Lookup::TYPES.each_key do |type|
        controller = Vms::Resources::Lookup::TYPES[type]
        http.stub_response(:post_json, "#{controller}/_Index", stub_lookup_response([]))
        result = lookup.list(type)
        expect(result[:statusCode]).to eq(200), "Expected 200 for #{type}, got #{result[:statusCode]}"
      end
    end

    it "uses large page_size to fetch all records" do
      http.stub_response(:post_json, "/County/_Index", stub_lookup_response([]))
      lookup.list("County")
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.body["size"]).to eq(9999)
    end
  end
end
