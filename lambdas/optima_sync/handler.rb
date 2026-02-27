# frozen_string_literal: true

require "json"
require_relative "../shared/logger"

# Lambda handler for pushing volunteer data to Optima (sync — API Gateway).
#
# TODO: Parse volunteer data from the request body
# TODO: Authenticate with Optima API
# TODO: Transform volunteer record into Optima's expected format
# TODO: POST volunteer data to Optima API
# TODO: Return sync result (success/failure, Optima reference ID)

def handler(event:, context:)
  Shared::Log.logger.info("optima_sync invoked — request_id=#{context.aws_request_id}")

  body = JSON.parse(event["body"] || "{}")

  {
    statusCode: 200,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(
      message: "optima_sync stub",
      request_id: context.aws_request_id,
      received: body
    )
  }
rescue StandardError => e
  Shared::Log.logger.error("optima_sync error: #{e.message}")

  {
    statusCode: 500,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: e.message)
  }
end
