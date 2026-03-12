# frozen_string_literal: true

require "aws-sdk-sqs"

module Aws
  class QueuePublisher
    def initialize
      @client = ::Aws::SQS::Client.new(sqs_client_options)
    end

    def enqueue_zoom_attendance(information_session_id:, zoom_meeting_id:)
      publish(
        queue_url: ENV.fetch("SQS_ZOOM_ATTENDANCE_URL"),
        message: {
          task: "zoom_attendance_sync",
          information_session_id: information_session_id,
          zoom_meeting_id: zoom_meeting_id,
          enqueued_at: Time.current.iso8601
        }
      )
    end

    def enqueue_mailchimp_batch(task:, payload: {})
      publish(
        queue_url: ENV.fetch("SQS_MAILCHIMP_BATCH_URL"),
        message: {
          task: task,
          payload: payload,
          enqueued_at: Time.current.iso8601
        }
      )
    end

    private

    def publish(queue_url:, message:)
      @client.send_message(
        queue_url: queue_url,
        message_body: message.to_json
      )
    end

    def sqs_client_options
      options = { region: ENV.fetch("AWS_REGION", "us-east-1") }

      if ENV["AWS_ENDPOINT_URL"].present?
        options[:endpoint] = ENV["AWS_ENDPOINT_URL"]
        options[:credentials] = ::Aws::Credentials.new("test", "test")
      end

      options
    end
  end
end
