class CommunicationTemplate < ApplicationRecord
  enum :template_type, { email: 0, sms: 1 }
  enum :funnel_stage, { inquiry: 0, application_eligible: 1, application_sent: 2 }
  enum :trigger_type, { interval: 0, event: 1, manual: 2, campaign: 3 }

  has_many :communications, dependent: :nullify
  has_many :scheduled_reminders, dependent: :destroy

  validates :name, presence: true
  validates :body, presence: true
  validates :funnel_stage, presence: true

  scope :active, -> { where(active: true) }
  scope :for_stage, ->(stage) { where(funnel_stage: stage) }
  scope :interval_triggers, -> { where(trigger_type: :interval) }
end
