class CreateReminderFrequencies < ActiveRecord::Migration[8.1]
  def change
    create_table :reminder_frequencies do |t|
      t.string :title

      t.timestamps
    end
  end
end
