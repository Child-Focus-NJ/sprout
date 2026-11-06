# frozen_string_literal: true

class RefreshQueuedEmailsJob < ApplicationJob
  queue_as :default

  def perform
    return unless ActiveModel::Type::Boolean.new.cast(ENV.fetch("SPROUT_EMAIL_MAILCHIMP_ENABLED", "false"))

    Communication.email.queued.where.not(external_id: [ nil, "" ]).find_each do |communication|
      Email::QueuedDelivery.refresh!(communication)
    rescue Mailchimp::TransactionalClient::Error
      # A missing message (including one not sent yet) or a failed lookup is not
      # proof of failure. Preserve the attempt and check again on the next run.
      Rails.logger.warn("Email status lookup failed for communication #{communication.id}; keeping it queued")
    end
  end
end
