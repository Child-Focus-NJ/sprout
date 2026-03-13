# frozen_string_literal: true

require "json"
require_relative "../shared/logger"

# Lambda handler for creating Zoom meetings (sync — API Gateway).
#
# TODO: Authenticate with Zoom API using OAuth server-to-server credentials
# TODO: Parse session details from the request body (topic, start_time, duration, etc.)
# TODO: Call Zoom Create Meeting API (POST /users/{userId}/meetings)
# TODO: Store the meeting ID and join URL in RDS (sessions table)
# TODO: Return the meeting join URL and meeting ID to the Rails app

def handler(event:, context:)
  Shared::Log.logger.info("zoom_meeting invoked — request_id=#{context.aws_request_id}")

  body = JSON.parse(event["body"] || "{}")

  {
    statusCode: 200,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(
      message: "zoom_meeting stub",
      request_id: context.aws_request_id,
      received: body
    )
  }
rescue StandardError => e
  Shared::Log.logger.error("zoom_meeting error: #{e.message}")

  {
    statusCode: 500,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: e.message)
  }
end
