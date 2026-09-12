# frozen_string_literal: true

class FollowUpReminderScheduler
  STALLED_STAGES = %w[inquiry application_eligible application_sent].freeze

  def self.call
    new.call
  end

  def call
    ActiveRecord::Base.transaction do
      Volunteer.where(current_funnel_stage: STALLED_STAGES).find_each do |volunteer|
        schedule_due_reminders_for(volunteer)
      end
    end
  end

  private

  def schedule_due_reminders_for(volunteer)
    days = volunteer.days_in_current_stage
    return if days.nil?

    templates_for(volunteer.current_funnel_stage).each do |template|
      next if days < template.interval_days
      next if already_scheduled?(volunteer.id, template.id)

      ScheduledReminder.create!(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: Time.current
      )
    end
  end

  def templates_for(stage)
    templates_by_stage[stage.to_s] || []
  end

  def templates_by_stage
    @templates_by_stage ||= CommunicationTemplate.active.stalled_stage_triggers.group_by(&:funnel_stage)
  end

  def already_scheduled?(volunteer_id, template_id)
    scheduled_pairs.include?([ volunteer_id, template_id ])
  end

  def scheduled_pairs
    @scheduled_pairs ||= ScheduledReminder.pluck(:volunteer_id, :communication_template_id).to_set
  end
end
