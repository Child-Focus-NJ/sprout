# frozen_string_literal: true

RSpec.describe Vms::Resources::Inquiry do
  let(:http) { FakeHttpClient.new }
  let(:inquiry) { described_class.new(http) }
  let(:kendo_body) do
    {
      "Data" => [
        { "InquiryID" => 1, "EncryptedID" => "enc1==", "FirstName" => "Jane",
          "LastName" => "Smith", "Email" => "jane@example.com", "Active" => true }
      ],
      "Total" => 1
    }.to_json
  end

  def stub_kendo_response
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, kendo_body)
    http.stub_response(:post_json, "/Inquiry/_Index", response)
    # Also stub for URL with query params
    http.stub_response(:post_json, "/Inquiry/_Index?active=active", response)
    http.stub_response(:post_json, "/Inquiry/_Index?active=inactive", response)
    response
  end

  def stub_edit_page
    html = '<input type="hidden" name="InquiryID" value="1" /><input type="hidden" name="Active" value="true" />'
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, html)
    http.stub_response(:get, "/Inquiry/Edit/enc1==", response)
    http.stub_hidden_fields("/Inquiry/Edit/enc1==", { "InquiryID" => "1", "Active" => "true" })
    response
  end

  describe "#list" do
    before { stub_kendo_response }

    it "returns 200 with paginated data" do
      result = inquiry.list({})
      expect(result[:statusCode]).to eq(200)
      body = JSON.parse(result[:body])
      expect(body["data"]).to be_an(Array)
      expect(body["total"]).to eq(1)
    end

    it "defaults to active status" do
      inquiry.list({})
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to include("active=active")
    end

    it "passes inactive status filter" do
      inquiry.list({ "status" => "inactive" })
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to include("active=inactive")
    end

    it "normalizes response fields to snake_case" do
      result = inquiry.list({})
      record = JSON.parse(result[:body])["data"].first
      expect(record).to have_key("first_name")
      expect(record).to have_key("inquiry_id")
    end

    it "uses default pagination params" do
      inquiry.list({})
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.body).to include("page" => 1, "size" => 50)
      expect(call.body["orderBy"]).to eq("Inquired-desc")
    end
  end

  describe "#create" do
    before { stub_kendo_response }

    it "maps snake_case body to PascalCase form data" do
      inquiry.create({
        "first_name" => "Jane", "last_name" => "Smith",
        "phone" => "555", "email" => "j@e.com", "gender" => 2, "inquired" => "03/15/2026"
      })
      call = http.calls.find { |c| c.method == :submit_form }
      expect(call.body["FirstName"]).to eq("Jane")
      expect(call.body["LastName"]).to eq("Smith")
      expect(call.body["Gender"]).to eq("2")
    end

    it "returns 201 with encrypted_id on success" do
      result = inquiry.create({
        "first_name" => "Jane", "last_name" => "Smith",
        "phone" => "555", "email" => "jane@example.com", "gender" => 2, "inquired" => "03/15/2026"
      })
      expect(result[:statusCode]).to eq(201)
      body = JSON.parse(result[:body])
      expect(body["success"]).to be true
      expect(body["encrypted_id"]).to eq("enc1==")
    end

    it "defaults county_id to Passaic (22967)" do
      inquiry.create({ "first_name" => "J", "last_name" => "S", "phone" => "5", "email" => "a@b.c", "gender" => 0, "inquired" => "01/01/2026" })
      call = http.calls.find { |c| c.method == :submit_form }
      expect(call.body["CountyID"]).to eq("22967")
    end
  end

  describe "#edit" do
    before { stub_edit_page }

    it "merges Active field into hidden fields and posts" do
      inquiry.edit("enc1==", { "active" => false })
      post_call = http.calls.find { |c| c.method == :post_form }
      expect(post_call.body["Active"]).to eq("false")
    end

    it "returns 200 on successful edit (302 redirect)" do
      result = inquiry.edit("enc1==", { "active" => false })
      expect(result[:statusCode]).to eq(200)
    end

    it "includes party_id when provided" do
      inquiry.edit("enc1==", { "active" => true, "party_id" => 999 })
      post_call = http.calls.find { |c| c.method == :post_form }
      expect(post_call.body["PartyID"]).to eq("999")
    end
  end

  describe "#delete" do
    it "returns 200 on success" do
      html = '<input type="hidden" name="EncryptedID" value="enc1==" />'
      get_response = Net::HTTPOK.new("1.1", "200", "OK")
      get_response.instance_variable_set(:@read, true)
      get_response.instance_variable_set(:@body, html)
      http.stub_response(:get, "/Inquiry/Delete/enc1==", get_response)
      http.stub_hidden_fields("/Inquiry/Delete/enc1==", { "EncryptedID" => "enc1==" })

      result = inquiry.delete("enc1==")
      expect(result[:statusCode]).to eq(200)
      expect(JSON.parse(result[:body])["success"]).to be true
    end
  end
end
