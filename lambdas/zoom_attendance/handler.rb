# frozen_string_literal: true

require "json"
require_relative "../shared/logger"

# Lambda handler for syncing Zoom attendance data (async — SQS).
#
# Triggered by SQS messages enqueued by the Rails app after a Zoom session ends.
# Each message contains a meeting_id to fetch participants for.
#
# TODO: Parse meeting_id from SQS message body
# TODO: Authenticate with Zoom API using OAuth server-to-server credentials
# TODO: Fetch meeting participants from Zoom (GET /past_meetings/{meetingId}/participants)
# TODO: Match participant emails to volunteers in RDS
# TODO: Write attendance records to the attendances table in RDS
# TODO: Handle pagination for meetings with many participants

def handler(event:, context:)
  Shared::Log.logger.info("zoom_attendance invoked — request_id=#{context.aws_request_id}")

  records = event["Records"] || []
  Shared::Log.logger.info("zoom_attendance processing #{records.length} SQS record(s)")

  records.each do |record|
    body = JSON.parse(record["body"])
    Shared::Log.logger.info("zoom_attendance processing message_id=#{record['messageId']}")

    # TODO: Implement attendance sync for meeting_id from body
    Shared::Log.logger.info("zoom_attendance stub — received: #{body.inspect}")
  end

  # Return nil for async handlers; errors must be raised so SQS retries.
  nil
rescue StandardError => e
  Shared::Log.logger.error("zoom_attendance error: #{e.message}")
  raise # Re-raise so SQS retries the message
end
