# frozen_string_literal: true

require "json"
require_relative "../shared/logger"

# Lambda handler for batch MailChimp operations (async — SQS + EventBridge).
#
# Two trigger sources:
#   1. SQS messages — ad-hoc batch tasks enqueued by Rails
#   2. EventBridge scheduled event — nightly audience reconciliation
#
# TODO: Implement full audience reconciliation (sync all volunteers to MailChimp)
# TODO: Implement campaign report pulls (fetch send/open/click stats)
# TODO: Authenticate with MailChimp API using API key
# TODO: Handle pagination for large audience lists
# TODO: Write reconciliation results back to RDS

def handler(event:, context:)
  Shared::Log.logger.info("mailchimp_batch invoked — request_id=#{context.aws_request_id}")

  if event["source"] == "aws.events"
    # EventBridge scheduled event (nightly cron)
    handle_scheduled_event(event: event, context: context)
  else
    # SQS messages
    handle_sqs_records(event: event, context: context)
  end
rescue StandardError => e
  Shared::Log.logger.error("mailchimp_batch error: #{e.message}")
  raise # Re-raise so SQS retries the message (or surfaces EventBridge failure)
end

private

def handle_scheduled_event(event:, context:)
  Shared::Log.logger.info("mailchimp_batch handling EventBridge scheduled event")

  # TODO: Run full audience reconciliation
  # TODO: Pull campaign reports
  Shared::Log.logger.info("mailchimp_batch scheduled event stub — detail_type=#{event['detail-type']}")

  nil
end

def handle_sqs_records(event:, context:)
  records = event["Records"] || []
  Shared::Log.logger.info("mailchimp_batch processing #{records.length} SQS record(s)")

  records.each do |record|
    body = JSON.parse(record["body"])
    Shared::Log.logger.info("mailchimp_batch processing message_id=#{record['messageId']}")

    # TODO: Implement batch task processing based on message content
    Shared::Log.logger.info("mailchimp_batch stub — received: #{body.inspect}")
  end

  nil
end
