class CommunicationTemplate < ApplicationRecord
  enum :template_type, { email: 0, sms: 1 }
  enum :funnel_stage, { inquiry: 0, application_eligible: 1, application_sent: 2 }
  enum :trigger_type, { interval: 0, event: 1, manual: 2, campaign: 3 }

  MERGE_FIELDS = %w[first_name last_name full_name email phone current_date organization_name].freeze
  ORGANIZATION_NAME = "Child Focus NJ"

  FOLLOW_UP_INTERVAL_DAYS = [ 30, 60, 90, 180 ].freeze

  has_many :communications, dependent: :nullify
  has_many :scheduled_reminders, dependent: :destroy

  validates :name, presence: true
  validates :body, presence: true
  validates :funnel_stage, presence: true

  scope :active, -> { where(active: true) }
  scope :for_stage, ->(stage) { where(funnel_stage: stage) }
  scope :interval_triggers, -> { where(trigger_type: :interval) }
  scope :for_interval_days, ->(days) { where(interval_days: days) }
  scope :stalled_stage_triggers, -> { interval_triggers.where.not(interval_days: nil) }

  def render_subject(volunteer = nil)
    render_text(subject, volunteer)
  end

  def render_body(volunteer = nil)
    render_text(body, volunteer)
  end

  private

  def render_text(text, volunteer)
    merge_values(volunteer).reduce(text.to_s) do |rendered, (token, value)|
      rendered.gsub("{{#{token}}}", value.to_s)
    end
  end

  def merge_values(volunteer)
    {
      "first_name" => volunteer&.first_name,
      "last_name" => volunteer&.last_name,
      "full_name" => volunteer&.full_name,
      "email" => volunteer&.email,
      "phone" => volunteer&.phone,
      "current_date" => Date.current.strftime("%B %-d, %Y"),
      "organization_name" => ORGANIZATION_NAME
    }
  end
end
