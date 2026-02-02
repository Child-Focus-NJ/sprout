class CreateScheduledReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_reminders do |t|
      t.references :volunteer, null: false, foreign_key: true
      t.references :communication_template, null: false, foreign_key: true
      t.datetime :scheduled_for, null: false
      t.integer :status, default: 0, null: false
      t.datetime :sent_at
      t.string :skip_reason

      t.timestamps
    end

    add_index :scheduled_reminders, [ :volunteer_id, :status ]
    add_index :scheduled_reminders, [ :scheduled_for, :status ]
  end
end
