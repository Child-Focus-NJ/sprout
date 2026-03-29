class Communication < ApplicationRecord
  enum :communication_type, { email: 0, sms: 1 }
  enum :status, { pending: 0, sent: 1, delivered: 2, failed: 3, bounced: 4 }

  belongs_to :volunteer
  belongs_to :communication_template, optional: true
  belongs_to :sent_by_user, class_name: "User", optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }

  after_create :mark_sms_delivered_if_seeded
  after_create :create_automatic_note_for_sent_reminder

  private

  def mark_sms_delivered_if_seeded
    return unless sms? && sent_at.present? && pending?

    update!(status: :delivered)
  end

  def create_automatic_note_for_sent_reminder
    return unless sent_by_user.present? && sent_at.present?

    volunteer.notes.create!(
      user: sent_by_user,
      note_type: :communication,
      content: "Reminder #{communication_type} sent at #{sent_at.strftime('%m/%d/%Y %H:%M')}"
    )
  end
end
