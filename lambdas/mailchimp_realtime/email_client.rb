# frozen_string_literal: true

require "json"
require "net/http"

module MailchimpRealtime
  class EmailClient
    ENDPOINT = URI("https://mandrillapp.com/api/1.4/messages/send")
    STATUSES = %w[sent queued scheduled rejected invalid].freeze

    class Error < StandardError
      attr_reader :status

      def initialize(message, status:)
        @status = status
        super(message)
      end
    end

    def deliver(body)
      validate!(body)
      api_key = ENV["MAILCHIMP_API_KEY"].to_s.strip
      sender = ENV["MAILCHIMP_EMAIL_FROM"].to_s.strip
      if api_key.empty? || !sender.match?(URI::MailTo::EMAIL_REGEXP)
        raise Error.new("Configure MAILCHIMP_API_KEY and MAILCHIMP_EMAIL_FROM on the Lambda", status: 503)
      end

      request = Net::HTTP::Post.new(ENDPOINT, "Content-Type" => "application/json")
      request.body = JSON.generate(
        key: api_key,
        message: {
          from_email: sender, to: [ { email: body["to"], type: "to" } ],
          subject: body["subject"], text: body["text_body"], merge: false
        }
      )
      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      http.write_timeout = 5
      http.max_retries = 0
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        status = response.code.to_i >= 500 ? 502 : 422
        raise Error.new("Mailchimp did not accept the email request (HTTP #{response.code})", status: status)
      end

      results = JSON.parse(response.body)
      result = results.first if results.is_a?(Array) && results.length == 1
      unless result.is_a?(Hash) && result["email"].is_a?(String) && result["email"].casecmp?(body["to"]) &&
          STATUSES.include?(result["status"]) && result["_id"].is_a?(String) && !result["_id"].strip.empty?
        raise Error.new("Mailchimp returned an unrecognized email result", status: 502)
      end

      { status: result["status"], external_id: result["_id"], to: result["email"], reject_reason: result["reject_reason"] }
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError => e
      raise Error.new("Mailchimp delivery could not be confirmed (#{e.class})", status: 502)
    end

    private

    def validate!(body)
      unless body.is_a?(Hash) && body["to"].is_a?(String) && body["to"].match?(URI::MailTo::EMAIL_REGEXP) &&
          body["subject"].is_a?(String) && !body["subject"].strip.empty? && body["subject"].length <= 998 && !body["subject"].match?(/[\r\n]/) &&
          body["text_body"].is_a?(String) && !body["text_body"].strip.empty?
        raise Error.new("A valid recipient, single-line subject, and email message are required", status: 400)
      end
    end
  end
end
