# frozen_string_literal: true

require "json"
require "logger"
require_relative "sms_client"
require_relative "email_client"

module MailchimpRealtime
  def self.response(status, body)
    { statusCode: status, headers: { "Content-Type" => "application/json" }, body: JSON.generate(body) }
  end

  def self.handler(event:, context:)
    action = event.fetch("path", "").split("/").last
    unless %w[send-email send-sms member tags].include?(action)
      return response(404, error: "Unknown Mailchimp action")
    end
    return response(501, error: "Mailchimp action is not implemented") unless %w[send-sms send-email].include?(action)

    body = JSON.parse(event["body"] || "{}")
    client = action == "send-sms" ? SmsClient.new : EmailClient.new
    response(200, client.deliver(body))
  rescue JSON::ParserError
    response(400, error: "Request body must be valid JSON")
  rescue SmsClient::Error, EmailClient::Error => e
    response(e.status, error: e.message)
  rescue StandardError => e
    Logger.new($stdout).error("mailchimp_realtime request_id=#{context.aws_request_id} error=#{e.class}")
    response(500, error: "Mailchimp request could not be completed")
  end
end

def handler(event:, context:)
  MailchimpRealtime.handler(event: event, context: context)
end
