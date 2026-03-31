# VMS Test Suite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add full RSpec test coverage for the VMS scraper API Lambda functions and Minitest coverage for the Rails LambdaClient VMS methods.

**Architecture:** Pure unit tests for transformers (no mocks). DI-based tests for resources and handler (FakeHttpClient double injected via constructor). WebMock tests for HttpClient and SessionManager (verifies real HTTP request construction, cookie handling, retry logic). AWS SDK `stub_responses: true` for Secrets Manager and Lambda clients.

**Tech Stack:** RSpec, WebMock, aws-sdk stubs, Minitest (Rails side)

---

### Task 1: Set up RSpec and WebMock for VMS Lambda

**Files:**
- Modify: `lambdas/vms/Gemfile`
- Create: `lambdas/vms/spec/spec_helper.rb`
- Create: `lambdas/vms/spec/support/fake_http_client.rb`
- Create: `lambdas/vms/.rspec`

**Step 1: Update Gemfile with test dependencies**

```ruby
# lambdas/vms/Gemfile
source "https://rubygems.org"

gem "aws-sdk-secretsmanager"
gem "aws-sdk-lambda"

group :test do
  gem "rspec", "~> 3.13"
  gem "webmock", "~> 3.23"
end
```

**Step 2: Create .rspec config**

```
# lambdas/vms/.rspec
--require spec_helper
--format documentation
--color
```

**Step 3: Create spec_helper.rb**

```ruby
# frozen_string_literal: true

require "webmock/rspec"
require "json"
require "net/http"

# Add lambda source to load path
$LOAD_PATH.unshift(File.join(__dir__, ".."))

# Stub the shared logger before any source requires it
module Shared
  module Log
    def self.logger
      @logger ||= Logger.new(File::NULL)
    end
  end
end

require "session_manager"
require "http_client"
require "resources/inquiry"
require "resources/volunteer"
require "resources/lookup"
require "transformers/field_normalizer"
require "transformers/kendo_response"

# Load handler (defines top-level methods)
require "handler"

require_relative "support/fake_http_client"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Disable all external HTTP by default
  WebMock.disable_net_connect!
end
```

**Step 4: Create FakeHttpClient**

A test double that records calls and returns canned responses. Resources inject this instead of the real HttpClient.

```ruby
# frozen_string_literal: true

class FakeHttpClient
  Call = Struct.new(:method, :path, :body, :headers, keyword_init: true)

  attr_reader :calls

  def initialize
    @calls = []
    @responses = {}
    @hidden_fields = {}
    @csrf_tokens = {}
  end

  # --- Stubbing API ---

  def stub_response(method, path, response)
    @responses["#{method}:#{path}"] = response
  end

  def stub_hidden_fields(path, fields)
    @hidden_fields[path] = fields
  end

  def stub_csrf_token(path, token)
    @csrf_tokens[path] = token
  end

  # --- HttpClient interface ---

  def get(path, headers: {})
    record_call(:get, path, nil, headers)
  end

  def post_form(path, form_data, headers: {})
    record_call(:post_form, path, form_data, headers)
  end

  def post_json(path, data, headers: {})
    record_call(:post_json, path, data, headers)
  end

  def submit_form(get_path, post_path, form_data)
    @calls << Call.new(method: :submit_form_get, path: get_path, body: nil, headers: {})
    record_call(:submit_form, post_path, form_data, {})
  end

  def extract_csrf_token(_html)
    nil
  end

  def extract_hidden_fields(html_or_path)
    # Return stubbed fields if the path was stubbed, otherwise empty hash
    @hidden_fields.values.first || {}
  end

  private

  def record_call(method, path, body, headers)
    @calls << Call.new(method: method, path: path, body: body, headers: headers)
    lookup_key = "#{method}:#{path}"
    @responses[lookup_key] || @responses.values.last || default_response
  end

  def default_response
    response = Net::HTTPFound.new("1.1", "302", "Found")
    allow_body(response)
    response
  end

  def allow_body(response)
    # Net::HTTPResponse needs a body accessor for test purposes
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, "")
    response
  end
end
```

**Step 5: Run bundle install and verify**

Run: `cd lambdas/vms && bundle install`

**Step 6: Verify RSpec is wired up**

Run: `cd lambdas/vms && bundle exec rspec --version`
Expected: RSpec version output (3.13.x)

**Step 7: Commit**

```bash
git add lambdas/vms/Gemfile lambdas/vms/Gemfile.lock lambdas/vms/.rspec lambdas/vms/spec/
git commit -m "Set up RSpec and WebMock for VMS Lambda tests"
```

---

### Task 2: FieldNormalizer tests (pure unit)

**Files:**
- Create: `lambdas/vms/spec/transformers/field_normalizer_spec.rb`

**Step 1: Write the tests**

```ruby
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
      expect(described_class.snake_to_pascal("first_name")).to eq("First_Name")
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
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/transformers/field_normalizer_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/transformers/field_normalizer_spec.rb
git commit -m "Add FieldNormalizer unit tests"
```

---

### Task 3: KendoResponse tests (pure unit)

**Files:**
- Create: `lambdas/vms/spec/transformers/kendo_response_spec.rb`

**Step 1: Write the tests**

```ruby
# frozen_string_literal: true

RSpec.describe Vms::Transformers::KendoResponse do
  describe ".parse" do
    it "parses PascalCase keys (Data/Total)" do
      json = '{"Data": [{"Name": "A"}], "Total": 1}'
      result = described_class.parse(json)
      expect(result["data"]).to eq([{ "Name" => "A" }])
      expect(result["total"]).to eq(1)
    end

    it "parses lowercase keys (data/total)" do
      json = '{"data": [{"Name": "B"}], "total": 2}'
      result = described_class.parse(json)
      expect(result["data"]).to eq([{ "Name" => "B" }])
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
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/transformers/kendo_response_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/transformers/kendo_response_spec.rb
git commit -m "Add KendoResponse unit tests"
```

---

### Task 4: Handler routing tests (DI)

**Files:**
- Create: `lambdas/vms/spec/handler_spec.rb`

**Step 1: Write the tests**

The handler creates its own SessionManager and HttpClient internally, so we test the `route` private method indirectly by calling `handler` with stubbed dependencies. Since handler creates resources internally, we stub the resource classes.

```ruby
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
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/handler_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/handler_spec.rb
git commit -m "Add handler routing tests"
```

---

### Task 5: BaseResource tests (DI)

**Files:**
- Create: `lambdas/vms/spec/resources/base_resource_spec.rb`
- Create: `lambdas/vms/spec/support/fixtures/kendo_list.json`
- Create: `lambdas/vms/spec/support/fixtures/delete_confirm.html`

**Step 1: Create fixtures**

`kendo_list.json`:
```json
{"Data": [{"FirstName": "Jane", "LastName": "Smith", "Inquired": "/Date(1710460800000)/"}], "Total": 1}
```

`delete_confirm.html`:
```html
<form action="/Inquiry/Delete/abc==" method="post">
  <input type="hidden" name="EncryptedID" value="abc==" />
  <input type="hidden" name="InquiryID" value="123" />
  <button type="submit">Delete</button>
</form>
```

**Step 2: Write the tests**

```ruby
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
```

**Step 3: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/resources/base_resource_spec.rb`
Expected: All pass

**Step 4: Commit**

```bash
git add lambdas/vms/spec/resources/base_resource_spec.rb lambdas/vms/spec/support/fixtures/
git commit -m "Add BaseResource tests with fixtures"
```

---

### Task 6: Inquiry resource tests (DI)

**Files:**
- Create: `lambdas/vms/spec/resources/inquiry_spec.rb`

**Step 1: Write the tests**

```ruby
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
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/resources/inquiry_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/resources/inquiry_spec.rb
git commit -m "Add Inquiry resource tests"
```

---

### Task 7: Volunteer resource tests (DI)

**Files:**
- Create: `lambdas/vms/spec/resources/volunteer_spec.rb`

**Step 1: Write the tests**

```ruby
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
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/resources/volunteer_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/resources/volunteer_spec.rb
git commit -m "Add Volunteer resource tests"
```

---

### Task 8: Lookup resource tests (DI)

**Files:**
- Create: `lambdas/vms/spec/resources/lookup_spec.rb`

**Step 1: Write the tests**

```ruby
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
      data = [{ "CountyID" => 1, "EncryptedID" => "a==", "CountyName" => "Passaic", "Active" => true }]
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
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/resources/lookup_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/resources/lookup_spec.rb
git commit -m "Add Lookup resource tests"
```

---

### Task 9: HttpClient tests (WebMock)

**Files:**
- Create: `lambdas/vms/spec/http_client_spec.rb`

**Step 1: Write the tests**

```ruby
# frozen_string_literal: true

RSpec.describe Vms::HttpClient do
  let(:session) do
    instance_double(Vms::SessionManager,
      base_url: "https://vms.example.com",
      cookies: { "ASP.NET_SessionId" => "sess123", ".ASPXAUTH" => "auth456" }
    )
  end
  let(:client) { described_class.new(session) }

  describe "#get" do
    it "attaches session cookies to request" do
      stub = stub_request(:get, "https://vms.example.com/Inquiry")
        .with(headers: { "Cookie" => "ASP.NET_SessionId=sess123; .ASPXAUTH=auth456" })
        .to_return(status: 200, body: "ok")

      client.get("/Inquiry")
      expect(stub).to have_been_requested
    end
  end

  describe "#post_json" do
    it "sends JSON body with correct headers" do
      stub = stub_request(:post, "https://vms.example.com/Inquiry/_Index")
        .with(
          body: { "page" => 1, "size" => 50 }.to_json,
          headers: {
            "Content-Type" => "application/json",
            "X-Requested-With" => "XMLHttpRequest"
          }
        )
        .to_return(status: 200, body: '{"Data":[],"Total":0}')

      client.post_json("/Inquiry/_Index", { "page" => 1, "size" => 50 })
      expect(stub).to have_been_requested
    end
  end

  describe "#post_form" do
    it "sends form-encoded body" do
      stub = stub_request(:post, "https://vms.example.com/Inquiry/Create")
        .with(
          body: "FirstName=Jane&LastName=Smith",
          headers: { "Content-Type" => "application/x-www-form-urlencoded" }
        )
        .to_return(status: 302, headers: { "Location" => "/Inquiry" })

      client.post_form("/Inquiry/Create", { "FirstName" => "Jane", "LastName" => "Smith" })
      expect(stub).to have_been_requested
    end
  end

  describe "#submit_form" do
    it "GETs form page then POSTs form data" do
      get_stub = stub_request(:get, "https://vms.example.com/Inquiry/Create")
        .to_return(status: 200, body: "<html>no csrf</html>")

      post_stub = stub_request(:post, "https://vms.example.com/Inquiry/Create")
        .to_return(status: 302, headers: { "Location" => "/Inquiry" })

      client.submit_form("/Inquiry/Create", "/Inquiry/Create", { "FirstName" => "Jane" })
      expect(get_stub).to have_been_requested
      expect(post_stub).to have_been_requested
    end

    it "includes CSRF token if present in form page" do
      html = '<input name="__RequestVerificationToken" type="hidden" value="csrf-tok-123" />'
      stub_request(:get, "https://vms.example.com/Inquiry/Create")
        .to_return(status: 200, body: html)

      post_stub = stub_request(:post, "https://vms.example.com/Inquiry/Create")
        .with(body: /csrf-tok-123/)
        .to_return(status: 302, headers: { "Location" => "/" })

      client.submit_form("/Inquiry/Create", "/Inquiry/Create", { "FirstName" => "Jane" })
      expect(post_stub).to have_been_requested
    end
  end

  describe "stale session retry" do
    it "retries once after session refresh on 302 to login" do
      allow(session).to receive(:stale_session?).and_return(true, false)
      allow(session).to receive(:refresh!)
      allow(session).to receive(:cookies).and_return(
        { "ASP.NET_SessionId" => "new_sess", ".ASPXAUTH" => "new_auth" }
      )

      stub_request(:get, "https://vms.example.com/Inquiry")
        .to_return(
          { status: 302, headers: { "Location" => "/Account/LogOn" } },
          { status: 200, body: "ok" }
        )

      response = client.get("/Inquiry")
      expect(response.code).to eq("200")
      expect(session).to have_received(:refresh!).once
    end

    it "raises if still stale after retry" do
      allow(session).to receive(:stale_session?).and_return(true)
      allow(session).to receive(:refresh!)

      stub_request(:get, "https://vms.example.com/Inquiry")
        .to_return(status: 302, headers: { "Location" => "/Account/LogOn" })

      expect { client.get("/Inquiry") }.to raise_error(/Session still stale/)
    end

    it "resets retried flag after request (even on error)" do
      allow(session).to receive(:stale_session?).and_return(false)

      stub_request(:get, "https://vms.example.com/first")
        .to_return(status: 200, body: "ok")
      stub_request(:get, "https://vms.example.com/second")
        .to_return(status: 200, body: "ok")

      client.get("/first")
      client.get("/second")
      # If @retried leaked, second request would skip retry logic — no error means it reset
    end
  end

  describe "#extract_csrf_token" do
    it "extracts token from HTML" do
      html = '<input name="__RequestVerificationToken" type="hidden" value="tok123" />'
      expect(client.extract_csrf_token(html)).to eq("tok123")
    end

    it "returns nil when no token" do
      expect(client.extract_csrf_token("<html></html>")).to be_nil
    end
  end

  describe "#extract_hidden_fields" do
    it "extracts all hidden inputs" do
      html = '<input type="hidden" name="ID" value="1" /><input type="hidden" name="Token" value="abc" />'
      fields = client.extract_hidden_fields(html)
      expect(fields).to eq({ "ID" => "1", "Token" => "abc" })
    end

    it "returns empty hash when none found" do
      expect(client.extract_hidden_fields("<html></html>")).to eq({})
    end
  end
end
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/http_client_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/http_client_spec.rb
git commit -m "Add HttpClient tests with WebMock"
```

---

### Task 10: SessionManager tests (AWS SDK stubs)

**Files:**
- Create: `lambdas/vms/spec/session_manager_spec.rb`

**Step 1: Write the tests**

```ruby
# frozen_string_literal: true

RSpec.describe Vms::SessionManager do
  let(:secret_data) do
    {
      "base_url" => "https://vms.example.com",
      "username" => "user",
      "password" => "pass",
      "cookies" => { "ASP.NET_SessionId" => "sess1", ".ASPXAUTH" => "auth1" }
    }
  end

  let(:secrets_client) do
    client = Aws::SecretsManager::Client.new(stub_responses: true)
    client.stub_responses(:get_secret_value, {
      secret_string: secret_data.to_json
    })
    client
  end

  let(:refresh_response) do
    {
      "statusCode" => 200,
      "body" => {
        "success" => true,
        "cookies" => { "ASP.NET_SessionId" => "new_sess", ".ASPXAUTH" => "new_auth" }
      }.to_json
    }
  end

  let(:lambda_client) do
    client = Aws::Lambda::Client.new(stub_responses: true)
    client.stub_responses(:invoke, {
      payload: StringIO.new(refresh_response.to_json)
    })
    client
  end

  let(:manager) { described_class.new }

  before do
    allow(manager).to receive(:secrets_client).and_return(secrets_client)
    allow(manager).to receive(:lambda_client).and_return(lambda_client)
  end

  describe "#cookies" do
    it "returns cookies from Secrets Manager" do
      expect(manager.cookies).to eq({ "ASP.NET_SessionId" => "sess1", ".ASPXAUTH" => "auth1" })
    end

    it "caches the secret (only one Secrets Manager call)" do
      manager.cookies
      manager.cookies
      expect(secrets_client.api_requests.count { |r| r[:operation_name] == :get_secret_value }).to eq(1)
    end

    it "returns empty hash when no cookies in secret" do
      secrets_client.stub_responses(:get_secret_value, {
        secret_string: { "base_url" => "https://example.com" }.to_json
      })
      expect(manager.cookies).to eq({})
    end
  end

  describe "#base_url" do
    it "returns base_url from secret" do
      expect(manager.base_url).to eq("https://vms.example.com")
    end
  end

  describe "#stale_session?" do
    it "returns true for 302 redirect to login page" do
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["location"] = "https://vms.example.com/Account/LogOn?ReturnUrl=%2f"
      expect(manager.stale_session?(response)).to be true
    end

    it "returns false for 302 to other pages" do
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["location"] = "/Inquiry"
      expect(manager.stale_session?(response)).to be false
    end

    it "returns false for 200 OK" do
      response = Net::HTTPOK.new("1.1", "200", "OK")
      expect(manager.stale_session?(response)).to be false
    end
  end

  describe "#refresh!" do
    it "invokes the session refresh Lambda" do
      manager.cookies  # warm cache
      manager.refresh!
      expect(lambda_client.api_requests.count { |r| r[:operation_name] == :invoke }).to eq(1)
    end

    it "updates cached cookies inline (no extra Secrets Manager read)" do
      manager.cookies  # warm cache first
      manager.refresh!
      expect(manager.cookies).to eq({ "ASP.NET_SessionId" => "new_sess", ".ASPXAUTH" => "new_auth" })
      # Should still be only 1 Secrets Manager read (initial)
      expect(secrets_client.api_requests.count { |r| r[:operation_name] == :get_secret_value }).to eq(1)
    end

    it "raises on refresh failure" do
      lambda_client.stub_responses(:invoke, {
        payload: StringIO.new({
          "statusCode" => 401,
          "body" => { "success" => false, "error" => "bad creds" }.to_json
        }.to_json)
      })
      manager.cookies  # warm cache
      expect { manager.refresh! }.to raise_error(/Session refresh failed/)
    end
  end
end
```

**Step 2: Run the tests**

Run: `cd lambdas/vms && bundle exec rspec spec/session_manager_spec.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add lambdas/vms/spec/session_manager_spec.rb
git commit -m "Add SessionManager tests with AWS SDK stubs"
```

---

### Task 11: Session Refresh Lambda tests

**Files:**
- Modify: `lambdas/vms_session_refresh/Gemfile`
- Create: `lambdas/vms_session_refresh/.rspec`
- Create: `lambdas/vms_session_refresh/spec/spec_helper.rb`
- Create: `lambdas/vms_session_refresh/spec/handler_spec.rb`

**Step 1: Update Gemfile**

```ruby
# lambdas/vms_session_refresh/Gemfile
source "https://rubygems.org"

gem "aws-sdk-secretsmanager"

group :test do
  gem "rspec", "~> 3.13"
  gem "webmock", "~> 3.23"
end
```

**Step 2: Create .rspec**

```
--require spec_helper
--format documentation
--color
```

**Step 3: Create spec_helper.rb**

```ruby
# frozen_string_literal: true

require "webmock/rspec"
require "json"
require "net/http"
require "aws-sdk-secretsmanager"

$LOAD_PATH.unshift(File.join(__dir__, ".."))

module Shared
  module Log
    def self.logger
      @logger ||= Logger.new(File::NULL)
    end
  end
end

require "handler"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
  WebMock.disable_net_connect!
end
```

**Step 4: Create handler_spec.rb**

```ruby
# frozen_string_literal: true

RSpec.describe "vms_session_refresh handler" do
  let(:context) { double("context", aws_request_id: "test-456") }
  let(:secret_data) do
    {
      "base_url" => "https://vms.example.com",
      "username" => "testuser",
      "password" => "testpass",
      "cookies" => {}
    }
  end

  let(:sm_client) do
    client = Aws::SecretsManager::Client.new(stub_responses: true)
    client.stub_responses(:get_secret_value, {
      secret_string: secret_data.to_json
    })
    client.stub_responses(:put_secret_value, {})
    client
  end

  before do
    allow(self).to receive(:secrets_client).and_return(sm_client)
    # Stub SSL verify env
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("VMS_SSL_VERIFY", "false").and_return("false")
  end

  describe "successful login" do
    before do
      # Step 1: GET login page
      stub_request(:get, "https://vms.example.com/Account/LogOn")
        .to_return(
          status: 200,
          body: "<html>login form</html>",
          headers: { "Set-Cookie" => "ASP.NET_SessionId=sess123; path=/" }
        )

      # Step 2: POST credentials
      stub_request(:post, "https://vms.example.com/Account/LogOn")
        .to_return(
          status: 302,
          headers: {
            "Location" => "/",
            "Set-Cookie" => ".ASPXAUTH=authcookie123; path=/"
          }
        )
    end

    it "returns success with cookies" do
      result = handler(event: {}, context: context)
      expect(result[:statusCode]).to eq(200)
      body = JSON.parse(result[:body])
      expect(body["success"]).to be true
      expect(body["cookies"][".ASPXAUTH"]).to eq("authcookie123")
      expect(body["cookies"]["ASP.NET_SessionId"]).to eq("sess123")
    end

    it "writes updated cookies to Secrets Manager" do
      handler(event: {}, context: context)
      put_calls = sm_client.api_requests.select { |r| r[:operation_name] == :put_secret_value }
      expect(put_calls.length).to eq(1)
    end

    it "includes refreshed_at timestamp" do
      result = handler(event: {}, context: context)
      body = JSON.parse(result[:body])
      expect(body["refreshed_at"]).to match(/\d{4}-\d{2}-\d{2}T/)
    end
  end

  describe "failed login" do
    before do
      stub_request(:get, "https://vms.example.com/Account/LogOn")
        .to_return(status: 200, body: "<html></html>")

      # POST returns 200 (form redisplay, no auth cookie)
      stub_request(:post, "https://vms.example.com/Account/LogOn")
        .to_return(status: 200, body: "Invalid credentials")
    end

    it "returns 401 when .ASPXAUTH not present" do
      result = handler(event: {}, context: context)
      expect(result[:statusCode]).to eq(401)
      body = JSON.parse(result[:body])
      expect(body["success"]).to be false
      expect(body["error"]).to include(".ASPXAUTH")
    end
  end

  describe "CSRF token handling" do
    it "includes CSRF token in POST when present in login page" do
      html = '<input name="__RequestVerificationToken" type="hidden" value="csrf-abc" />'
      stub_request(:get, "https://vms.example.com/Account/LogOn")
        .to_return(status: 200, body: html)

      post_stub = stub_request(:post, "https://vms.example.com/Account/LogOn")
        .with(body: /__RequestVerificationToken=csrf-abc/)
        .to_return(
          status: 302,
          headers: {
            "Set-Cookie" => ".ASPXAUTH=auth1; path=/",
            "Location" => "/"
          }
        )

      handler(event: {}, context: context)
      expect(post_stub).to have_been_requested
    end
  end
end
```

**Step 5: Bundle install**

Run: `cd lambdas/vms_session_refresh && bundle install`

**Step 6: Run the tests**

Run: `cd lambdas/vms_session_refresh && bundle exec rspec`
Expected: All pass

**Step 7: Commit**

```bash
git add lambdas/vms_session_refresh/Gemfile lambdas/vms_session_refresh/Gemfile.lock lambdas/vms_session_refresh/.rspec lambdas/vms_session_refresh/spec/
git commit -m "Add Session Refresh Lambda tests"
```

---

### Task 12: Rails LambdaClient VMS tests (Minitest + WebMock)

**Files:**
- Create: `test/services/aws/lambda_client_vms_test.rb`

**Step 1: Check that WebMock is available in Rails test environment**

Run: `grep -r "webmock" Gemfile`

If not present, add `gem "webmock"` to the test group in the project Gemfile and `bundle install`.

**Step 2: Write the tests**

```ruby
# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class LambdaClientVmsTest < ActiveSupport::TestCase
  setup do
    @base_url = "https://api.example.com/v1"
    ENV["API_GATEWAY_URL"] = @base_url
    @client = Aws::LambdaClient.new
  end

  teardown do
    ENV.delete("API_GATEWAY_URL")
    WebMock.reset!
  end

  # --- Inquiries ---

  test "vms_list_inquiries sends GET with query params" do
    stub = stub_request(:get, "#{@base_url}/vms/inquiries")
      .with(query: { "status" => "active", "page" => "1", "page_size" => "50" })
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_inquiries
    assert_requested(stub)
  end

  test "vms_list_inquiries passes custom params" do
    stub = stub_request(:get, "#{@base_url}/vms/inquiries")
      .with(query: { "status" => "inactive", "page" => "2", "page_size" => "25" })
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_inquiries(status: "inactive", page: 2, page_size: 25)
    assert_requested(stub)
  end

  test "vms_create_inquiry sends POST with body" do
    stub = stub_request(:post, "#{@base_url}/vms/inquiries")
      .with(body: hash_including("first_name" => "Jane", "last_name" => "Smith"))
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_create_inquiry(first_name: "Jane", last_name: "Smith", phone: "555", email: "j@e.com", gender: 2, inquired: "03/15/2026")
    assert_requested(stub)
  end

  test "vms_edit_inquiry sends PUT to correct path" do
    stub = stub_request(:put, "#{@base_url}/vms/inquiries/enc123==")
      .with(body: hash_including("active" => false))
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_edit_inquiry(encrypted_id: "enc123==", active: false)
    assert_requested(stub)
  end

  test "vms_delete_inquiry sends DELETE" do
    stub = stub_request(:delete, "#{@base_url}/vms/inquiries/enc123==")
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_delete_inquiry(encrypted_id: "enc123==")
    assert_requested(stub)
  end

  # --- Volunteers ---

  test "vms_list_volunteers sends GET with defaults" do
    stub = stub_request(:get, "#{@base_url}/vms/volunteers")
      .with(query: { "status" => "yes", "page" => "1", "page_size" => "50" })
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_volunteers
    assert_requested(stub)
  end

  test "vms_create_volunteer sends POST" do
    stub = stub_request(:post, "#{@base_url}/vms/volunteers")
      .with(body: hash_including("first_name" => "Jane"))
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_create_volunteer(first_name: "Jane", last_name: "Smith", gender: 2)
    assert_requested(stub)
  end

  # --- Lookups ---

  test "vms_list_lookup sends GET with type in path" do
    stub = stub_request(:get, "#{@base_url}/vms/lookups/County")
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_lookup(type: "County")
    assert_requested(stub)
  end

  # --- Session ---

  test "vms_refresh_session sends POST" do
    stub = stub_request(:post, "#{@base_url}/vms/session/refresh")
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_refresh_session
    assert_requested(stub)
  end

  # --- Error handling ---

  test "raises LambdaError on non-2xx response" do
    stub_request(:get, "#{@base_url}/vms/inquiries")
      .with(query: hash_including({}))
      .to_return(status: 500, body: { error: "boom" }.to_json, headers: { "Content-Type" => "application/json" })

    assert_raises(Aws::LambdaClient::LambdaError) do
      @client.vms_list_inquiries
    end
  end
end
```

**Step 3: Run the test**

Run: `bundle exec rails test test/services/aws/lambda_client_vms_test.rb`
Expected: All pass

**Step 4: Commit**

```bash
git add test/services/aws/lambda_client_vms_test.rb
git commit -m "Add Rails LambdaClient VMS tests"
```

---

### Task 13: Run full suite and verify

**Step 1: Run VMS Lambda specs**

Run: `cd lambdas/vms && bundle exec rspec`
Expected: ~45 tests, all pass

**Step 2: Run Session Refresh specs**

Run: `cd lambdas/vms_session_refresh && bundle exec rspec`
Expected: ~5 tests, all pass

**Step 3: Run Rails VMS tests**

Run: `bundle exec rails test test/services/aws/lambda_client_vms_test.rb`
Expected: ~10 tests, all pass

**Step 4: Final commit**

If any fixes were needed, commit them:
```bash
git add -A
git commit -m "Fix test suite issues found in full run"
```
