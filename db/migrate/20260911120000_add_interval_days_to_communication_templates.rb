class AddIntervalDaysToCommunicationTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :communication_templates, :interval_days, :integer
    add_index :communication_templates, [ :funnel_stage, :interval_days ]
  end
end
