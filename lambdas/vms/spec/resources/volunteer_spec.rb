# frozen_string_literal: true

RSpec.describe Vms::Resources::Volunteer do
  let(:http) { FakeHttpClient.new }
  let(:volunteer) { described_class.new(http) }
  let(:kendo_body) do
    {
      "Data" => [
        { "PartyID" => 1, "EncyptedPartyID" => "enc1==", "FirstName" => "Jane",
          "LastName" => "Smith", "Gender" => "Female", "Active" => true }
      ],
      "Total" => 1
    }.to_json
  end

  before do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, kendo_body)
    http.stub_response(:post_json, "/Volunteers/_GridIndex", response)
    http.stub_response(:post_json, "/Volunteers/_GridIndex?active=yes", response)
    http.stub_response(:post_json, "/Volunteers/_GridIndex?active=no", response)
    http.stub_response(:post_json, "/Volunteers/_GridIndex?active=all", response)
  end

  describe "#list" do
    it "uses _GridIndex endpoint (not _Index)" do
      volunteer.list({})
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to include("_GridIndex")
    end

    it "defaults to status=yes" do
      volunteer.list({})
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to include("active=yes")
    end

    it "defaults order_by to LastName-asc" do
      volunteer.list({})
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.body["orderBy"]).to eq("LastName-asc")
    end

    it "normalizes VMS typo EncyptedPartyID" do
      result = volunteer.list({})
      record = JSON.parse(result[:body])["data"].first
      expect(record).to have_key("encrypted_party_id")
    end
  end

  describe "#create" do
    it "maps required fields to PascalCase" do
      volunteer.create({ "first_name" => "Jane", "last_name" => "Smith", "gender" => 2 })
      call = http.calls.find { |c| c.method == :submit_form }
      expect(call.body["FirstName"]).to eq("Jane")
      expect(call.body["Gender"]).to eq("2")
    end

    it "includes optional fields when present" do
      volunteer.create({
        "first_name" => "Jane", "last_name" => "Smith", "gender" => 2,
        "home_email" => "j@e.com", "cell_phone" => "555"
      })
      call = http.calls.find { |c| c.method == :submit_form }
      expect(call.body["HomeEmail"]).to eq("j@e.com")
      expect(call.body["CellPhone"]).to eq("555")
    end

    it "defaults permission fields to true" do
      volunteer.create({ "first_name" => "J", "last_name" => "S", "gender" => 0 })
      call = http.calls.find { |c| c.method == :submit_form }
      expect(call.body["PermissionToCall"]).to eq("true")
      expect(call.body["ShareInfoPermission"]).to eq("true")
    end

    it "defaults county to Passaic" do
      volunteer.create({ "first_name" => "J", "last_name" => "S", "gender" => 0 })
      call = http.calls.find { |c| c.method == :submit_form }
      expect(call.body["CountyID"]).to eq("22967")
    end

    it "returns 201 on success" do
      result = volunteer.create({ "first_name" => "J", "last_name" => "S", "gender" => 0 })
      expect(result[:statusCode]).to eq(201)
    end
  end
end
