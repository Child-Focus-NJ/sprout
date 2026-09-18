class ReorderScheduledRemindersStatusIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :scheduled_reminders, [ :scheduled_for, :status ]
    add_index :scheduled_reminders, [ :status, :scheduled_for ]
  end
end
