# frozen_string_literal: true

RSpec.describe "handler" do
  let(:context) { double("context", aws_request_id: "test-123") }

  def build_event(method:, path:, body: {}, query: {}, path_params: {})
    {
      "httpMethod" => method,
      "path" => path,
      "body" => body.to_json,
      "queryStringParameters" => query,
      "pathParameters" => path_params
    }
  end

  before do
    # Stub SessionManager and HttpClient to avoid AWS calls
    session = instance_double(Vms::SessionManager)
    allow(Vms::SessionManager).to receive(:new).and_return(session)
    allow(Vms::HttpClient).to receive(:new).with(session).and_return(FakeHttpClient.new)
  end

  describe "inquiry routing" do
    let(:inquiry_double) { instance_double(Vms::Resources::Inquiry) }

    before do
      allow(Vms::Resources::Inquiry).to receive(:new).and_return(inquiry_double)
    end

    it "routes GET /vms/inquiries to inquiry.list" do
      expect(inquiry_double).to receive(:list).with({ "status" => "active" }).and_return(statusCode: 200, body: "{}")
      handler(event: build_event(method: "GET", path: "/vms/inquiries", query: { "status" => "active" }), context: context)
    end

    it "routes POST /vms/inquiries to inquiry.create" do
      body = { "first_name" => "Jane" }
      expect(inquiry_double).to receive(:create).with(body).and_return(statusCode: 201, body: "{}")
      handler(event: build_event(method: "POST", path: "/vms/inquiries", body: body), context: context)
    end

    it "routes PUT /vms/inquiries/{id} to inquiry.edit" do
      expect(inquiry_double).to receive(:edit).with("abc==", { "active" => false }).and_return(statusCode: 200, body: "{}")
      handler(event: build_event(method: "PUT", path: "/vms/inquiries/abc==", body: { "active" => false }, path_params: { "id" => "abc==" }), context: context)
    end

    it "routes DELETE /vms/inquiries/{id} to inquiry.delete" do
      expect(inquiry_double).to receive(:delete).with("abc==").and_return(statusCode: 200, body: "{}")
      handler(event: build_event(method: "DELETE", path: "/vms/inquiries/abc==", path_params: { "id" => "abc==" }), context: context)
    end

    it "returns 405 for PATCH on inquiries" do
      result = handler(event: build_event(method: "PATCH", path: "/vms/inquiries"), context: context)
      expect(result[:statusCode]).to eq(405)
    end

    it "returns 400 for PUT without id" do
      allow(inquiry_double).to receive(:edit)
      result = handler(event: build_event(method: "PUT", path: "/vms/inquiries"), context: context)
      expect(result[:statusCode]).to eq(400)
    end
  end

  describe "volunteer routing" do
    let(:volunteer_double) { instance_double(Vms::Resources::Volunteer) }

    before do
      allow(Vms::Resources::Volunteer).to receive(:new).and_return(volunteer_double)
    end

    it "routes GET /vms/volunteers to volunteer.list" do
      expect(volunteer_double).to receive(:list).with({}).and_return(statusCode: 200, body: "{}")
      handler(event: build_event(method: "GET", path: "/vms/volunteers"), context: context)
    end

    it "routes POST /vms/volunteers to volunteer.create" do
      body = { "first_name" => "Jane" }
      expect(volunteer_double).to receive(:create).with(body).and_return(statusCode: 201, body: "{}")
      handler(event: build_event(method: "POST", path: "/vms/volunteers", body: body), context: context)
    end

    it "returns 405 for DELETE on volunteers" do
      result = handler(event: build_event(method: "DELETE", path: "/vms/volunteers"), context: context)
      expect(result[:statusCode]).to eq(405)
    end
  end

  describe "lookup routing" do
    let(:lookup_double) { instance_double(Vms::Resources::Lookup) }

    before do
      allow(Vms::Resources::Lookup).to receive(:new).and_return(lookup_double)
    end

    it "routes GET /vms/lookups/County to lookup.list" do
      expect(lookup_double).to receive(:list).with("County").and_return(statusCode: 200, body: "{}")
      handler(event: build_event(method: "GET", path: "/vms/lookups/County", path_params: { "type" => "County" }), context: context)
    end
  end

  describe "error handling" do
    it "returns 404 for unknown resource" do
      result = handler(event: build_event(method: "GET", path: "/vms/unknown"), context: context)
      expect(result[:statusCode]).to eq(404)
      expect(JSON.parse(result[:body])["error"]).to include("Unknown resource")
    end

    it "returns 500 on unexpected exception" do
      allow(Vms::SessionManager).to receive(:new).and_raise(StandardError, "boom")
      result = handler(event: build_event(method: "GET", path: "/vms/inquiries"), context: context)
      expect(result[:statusCode]).to eq(500)
      expect(JSON.parse(result[:body])["error"]).to eq("boom")
    end
  end
end
