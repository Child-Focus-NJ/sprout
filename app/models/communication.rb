class Communication < ApplicationRecord
  enum :communication_type, { email: 0, sms: 1 }
  enum :status, { pending: 0, sent: 1, delivered: 2, failed: 3, bounced: 4 }

  belongs_to :volunteer
  belongs_to :communication_template, optional: true
  belongs_to :sent_by_user, class_name: "User", optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }

  after_save :promote_pending_sms_to_delivered
  after_save :log_staff_note_for_outbound_send

  private

  # When an SMS is recorded as sent locally (sent_at set, still pending), mark delivered for UI/history.
  def promote_pending_sms_to_delivered
    return unless sms?
    return unless sent_at.present? && pending?

    update_column(:status, Communication.statuses[:delivered])
  end

  def log_staff_note_for_outbound_send
    return unless sent_by_user.present? && sent_at.present?
    return unless saved_change_to_sent_at?
    prev, curr = saved_change_to_sent_at
    return if prev.present? || curr.blank?

    volunteer.notes.create!(
      user: sent_by_user,
      note_type: :communication,
      content: "Reminder #{communication_type} sent at #{sent_at.strftime('%m/%d/%Y %H:%M')}"
    )
  end
end
