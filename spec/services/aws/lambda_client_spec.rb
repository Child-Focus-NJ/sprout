# frozen_string_literal: true

require "rails_helper"

RSpec.describe Aws::LambdaClient do
  include_context "Mailchimp SMS enabled"

  let(:params) { { to: "+12015550123", message: "Hello", consent: "onetime" } }

  it "passes consent with the recipient and message" do
    response = double(success?: true, body: '{"status":"queued"}')
    expect(HTTParty).to receive(:post).with("http://gateway.test/mailchimp/send-sms",
      hash_including(body: params.to_json)).and_return(response)
    expect(described_class.new.send_sms(**params)).to eq("status" => "queued")
  end

  it "fails clearly when no gateway is configured" do
    ENV.delete("API_GATEWAY_URL")
    expect { described_class.new.send_sms(**params) }.to raise_error(described_class::LambdaError, /Set API_GATEWAY_URL/)
  end

  it "treats malformed success responses and network timeouts as uncertain delivery" do
    allow(HTTParty).to receive(:post).and_return(double(success?: true, body: "not JSON"))
    expect { described_class.new.send_sms(**params) }.to raise_error(described_class::UncertainDeliveryError)
    allow(HTTParty).to receive(:post).and_raise(Net::ReadTimeout)
    expect { described_class.new.send_sms(**params) }.to raise_error(described_class::UncertainDeliveryError)
  end

  it "handles non-JSON gateway failures without echoing the response" do
    allow(HTTParty).to receive(:post).and_return(double(success?: false, code: 503, body: "private details"))
    expect { described_class.new.send_sms(**params) }.to raise_error(described_class::LambdaError, "Lambda /mailchimp/send-sms returned 503")
  end

  it "treats gateway timeouts and provider failures as uncertain" do
    [ 500, 502, 504 ].each do |status|
      allow(HTTParty).to receive(:post).and_return(double(success?: false, code: status))
      expect { described_class.new.send_sms(**params) }.to raise_error(described_class::UncertainDeliveryError)
    end
  end
end
