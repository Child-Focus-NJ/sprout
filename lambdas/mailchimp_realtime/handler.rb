# frozen_string_literal: true

require "json"
require_relative "../shared/logger"

# Lambda handler for real-time MailChimp/Mandrill operations (sync — API Gateway).
#
# Sprout sends transactional email and SMS from Rails through Mailchimp::TransactionalClient.
# This handler is still a stub. It does not send email, and Rails does not call it.
#
# Routes requests based on event["path"] to the appropriate action:
#   POST /mailchimp/send-email  — Not implemented. Rails sends email directly.
#   POST /mailchimp/send-sms    — Send SMS via Mandrill Transactional SMS
#   POST /mailchimp/member      — Add or update a MailChimp audience member
#   POST /mailchimp/tags        — Update member tags by funnel stage
#
# TODO: Authenticate with MailChimp/Mandrill API using API key
# TODO: Implement send-sms action (Mandrill transactional SMS endpoint)
# TODO: Implement member action (MailChimp lists/members endpoint — PUT for upsert)
# TODO: Implement tags action (MailChimp lists/members/{id}/tags endpoint)
# TODO: Validate request payloads for each action

ACTIONS = %w[send-email send-sms member tags].freeze

def handler(event:, context:)
  Shared::Log.logger.info("mailchimp_realtime invoked — request_id=#{context.aws_request_id}")

  path = event["path"] || ""
  action = path.split("/").last
  body = JSON.parse(event["body"] || "{}")

  unless ACTIONS.include?(action)
    return {
      statusCode: 404,
      headers: { "Content-Type" => "application/json" },
      body: JSON.generate(
        error: "Unknown action: #{action}",
        valid_actions: ACTIONS
      )
    }
  end

  Shared::Log.logger.info("mailchimp_realtime routing to action=#{action}")

  # TODO: Dispatch to the appropriate implementation based on action
  {
    statusCode: 200,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(
      message: "mailchimp_realtime stub",
      action: action,
      request_id: context.aws_request_id,
      received: body
    )
  }
rescue StandardError => e
  Shared::Log.logger.error("mailchimp_realtime error: #{e.message}")

  {
    statusCode: 500,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: e.message)
  }
end
