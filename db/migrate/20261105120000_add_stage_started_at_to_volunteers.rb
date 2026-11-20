class AddStageStartedAtToVolunteers < ActiveRecord::Migration[8.1]
  STAGE_NAMES = { 0 => "Inquiry", 1 => "Application eligible", 2 => "Application sent", 3 => "Applied", 4 => "Inactive" }.freeze

  def up
    add_column :volunteers, :stage_started_at, :datetime
    execute <<~SQL
      UPDATE volunteers SET stage_started_at = COALESCE(
        (SELECT MAX(status_changes.created_at) FROM status_changes
          WHERE status_changes.volunteer_id = volunteers.id
            AND status_changes.to_funnel_stage = CASE volunteers.current_funnel_stage #{stage_name_cases} END),
        CASE volunteers.current_funnel_stage
          WHEN 1 THEN volunteers.first_session_attended_at
          WHEN 2 THEN volunteers.application_sent_at
          WHEN 3 THEN volunteers.application_submitted_at
          WHEN 4 THEN volunteers.became_inactive_at
        END,
        volunteers.inquiry_date
      )
    SQL
    change_column_null :volunteers, :stage_started_at, false
    add_index :volunteers, :stage_started_at
  end

  def down
    remove_column :volunteers, :stage_started_at
  end

  private

  def stage_name_cases
    STAGE_NAMES.map { |stage, name| "WHEN #{stage} THEN #{connection.quote(name)}" }.join(" ")
  end
end
