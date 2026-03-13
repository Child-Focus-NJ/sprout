# frozen_string_literal: true

require "json"
require_relative "../shared/logger"

# Lambda handler for pushing volunteer data to the volunteer management system (sync — API Gateway).
#
# TODO: Parse volunteer data from the request body
# TODO: Authenticate with the volunteer management system API
# TODO: Transform volunteer record into the expected format
# TODO: POST volunteer data to the volunteer management system API
# TODO: Return sync result (success/failure, reference ID)

def handler(event:, context:)
  Shared::Log.logger.info("volunteer_management_system_sync invoked — request_id=#{context.aws_request_id}")

  body = JSON.parse(event["body"] || "{}")

  {
    statusCode: 200,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(
      message: "volunteer_management_system_sync stub",
      request_id: context.aws_request_id,
      received: body
    )
  }
rescue StandardError => e
  Shared::Log.logger.error("volunteer_management_system_sync error: #{e.message}")

  {
    statusCode: 500,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(error: e.message)
  }
end
