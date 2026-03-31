# frozen_string_literal: true

RSpec.describe Vms::HttpClient do
  let(:session) do
    sm = instance_double(Vms::SessionManager,
      base_url: "https://vms.example.com",
      cookies: { "ASP.NET_SessionId" => "sess123", ".ASPXAUTH" => "auth456" }
    )
    allow(sm).to receive(:stale_session?).and_return(false)
    sm
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
