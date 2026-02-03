class Communication < ApplicationRecord
  enum :communication_type, { email: 0, sms: 1 }
  enum :status, { pending: 0, sent: 1, delivered: 2, failed: 3, bounced: 4 }

  belongs_to :volunteer
  belongs_to :communication_template, optional: true
  belongs_to :sent_by_user, class_name: "User", optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
end
