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
