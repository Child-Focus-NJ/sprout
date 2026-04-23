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
