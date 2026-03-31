# frozen_string_literal: true

RSpec.describe Vms::Resources::BaseResource do
  let(:http) { FakeHttpClient.new }
  let(:resource) { described_class.new(http) }
  let(:fixtures) { File.join(__dir__, "..", "support", "fixtures") }

  describe "#kendo_list (via subclass)" do
    # BaseResource methods are protected — test via a subclass wrapper
    let(:test_class) do
      Class.new(described_class) do
        def test_list(path, params = {}, **opts)
          kendo_list(path, params, **opts)
        end
      end
    end
    let(:resource) { test_class.new(http) }

    before do
      body = File.read(File.join(fixtures, "kendo_list.json"))
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)
      http.stub_response(:post_json, "/Inquiry/_Index", response)
    end

    it "sends correct Kendo parameters" do
      resource.test_list("/Inquiry", { page: 2, page_size: 25, order_by: "Name-asc" })
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.body).to eq({ "page" => 2, "size" => 25, "orderBy" => "Name-asc" })
    end

    it "normalizes response records to snake_case" do
      result = resource.test_list("/Inquiry")
      expect(result["data"].first).to have_key("first_name")
      expect(result["data"].first).not_to have_key("FirstName")
    end

    it "includes pagination metadata" do
      result = resource.test_list("/Inquiry", { page: 1, page_size: 50 })
      expect(result).to include("page" => 1, "page_size" => 50, "total" => 1)
    end

    it "appends url_params as query string" do
      resource.test_list("/Inquiry", {}, url_params: { "active" => "yes" })
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to eq("/Inquiry/_Index?active=yes")
    end

    it "uses custom endpoint_suffix" do
      resource.test_list("/Volunteers", {}, endpoint_suffix: "_GridIndex")
      call = http.calls.find { |c| c.method == :post_json }
      expect(call.path).to include("_GridIndex")
    end
  end

  describe "#form_create" do
    let(:test_class) do
      Class.new(described_class) do
        def test_create(path, data)
          form_create(path, data)
        end
      end
    end
    let(:resource) { test_class.new(http) }

    it "returns success on 302 redirect" do
      result = resource.test_create("/Inquiry", { "FirstName" => "Jane" })
      expect(result).to eq({ "success" => true })
    end

    it "returns failure on non-redirect response" do
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, "form errors here")
      http.stub_response(:submit_form, "/Inquiry/Create", response)
      result = resource.test_create("/Inquiry", {})
      expect(result["success"]).to be false
      expect(result["error"]).to include("200")
    end
  end

  describe "#form_delete" do
    let(:test_class) do
      Class.new(described_class) do
        def test_delete(path, id)
          form_delete(path, id)
        end
      end
    end
    let(:resource) { test_class.new(http) }

    before do
      html = File.read(File.join(fixtures, "delete_confirm.html"))
      get_response = Net::HTTPOK.new("1.1", "200", "OK")
      get_response.instance_variable_set(:@read, true)
      get_response.instance_variable_set(:@body, html)
      http.stub_response(:get, "/Inquiry/Delete/abc==", get_response)
      http.stub_hidden_fields("/Inquiry/Delete/abc==", { "EncryptedID" => "abc==", "InquiryID" => "123" })
    end

    it "extracts hidden fields and posts to confirm" do
      result = resource.test_delete("/Inquiry", "abc==")
      expect(result).to eq({ "success" => true })
      post_call = http.calls.find { |c| c.method == :post_form }
      expect(post_call.body).to include("EncryptedID" => "abc==")
    end
  end

  describe "#api_response" do
    let(:test_class) do
      Class.new(described_class) do
        def test_api_response(status, body)
          api_response(status, body)
        end
      end
    end
    let(:resource) { test_class.new(http) }

    it "builds API Gateway response hash" do
      result = resource.test_api_response(200, { "ok" => true })
      expect(result[:statusCode]).to eq(200)
      expect(result[:headers]["Content-Type"]).to eq("application/json")
      expect(JSON.parse(result[:body])).to eq({ "ok" => true })
    end
  end
end
