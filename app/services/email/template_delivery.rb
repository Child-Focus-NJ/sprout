# frozen_string_literal: true

module Email
  # Sends a communication template to volunteers through TemplateMailer, recorded as a
  # Communication so it shows on their timeline.
  class TemplateDelivery
    BATCH_SIZE = 500
    NOT_QUEUED_MESSAGE = "Couldn't be queued for sending. Send it again."
    Result = Data.define(:queued, :not_queued)

    def self.record!(volunteer:, template:, sent_by_user: nil)
      Communication.create!(attributes_for(volunteer, template, sent_by_user))
    end

    # Records a pending email for each volunteer and queues it to send, a batch at a time, so a
    # whole tab takes a few queries instead of several per volunteer. Any the queue didn't accept
    # are marked failed straight away, so none sit "pending" on a timeline with nothing to send them.
    def self.deliver_all_later(volunteers, template:, sent_by_user: nil)
      queued = not_queued = 0
      volunteers.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        rows = batch.map { |volunteer| attributes_for(volunteer, template, sent_by_user) }
        ids = Communication.insert_all!(rows, returning: :id).rows.flatten
        jobs = ids.map { |id| SendTemplateEmailJob.new(id) }
        ActiveJob.perform_all_later(jobs)

        rejected_ids = jobs.reject(&:successfully_enqueued?).map { |job| job.arguments.first }
        if rejected_ids.any?
          Communication.where(id: rejected_ids)
                       .update_all(status: Communication.statuses[:failed], error_message: NOT_QUEUED_MESSAGE, updated_at: Time.current)
        end
        queued += jobs.size - rejected_ids.size
        not_queued += rejected_ids.size
      end
      Result.new(queued:, not_queued:)
    end

    # Marks the communication failed if the mailer raises, and sent once it accepts. A block runs
    # in the same transaction as marking it sent.
    def self.deliver!(communication)
      begin
        TemplateMailer.follow_up(communication).deliver_now
      rescue StandardError => e
        communication.update!(status: :failed, error_message: e.message.to_s.truncate(255))
        raise
      end

      ActiveRecord::Base.transaction do
        communication.update!(status: :sent, sent_at: Time.current)
        yield if block_given?
      end
      communication
    end

    def self.attributes_for(volunteer, template, sent_by_user)
      template.render_for(volunteer).merge(
        volunteer_id: volunteer.id,
        communication_template_id: template.id,
        communication_type: template.template_type,
        email_to: volunteer.email,
        sent_by_user_id: sent_by_user&.id,
        status: "pending"
      )
    end
    private_class_method :attributes_for
  end
end
