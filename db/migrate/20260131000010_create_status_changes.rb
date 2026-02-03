class CreateStatusChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :status_changes do |t|
      t.references :volunteer, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :from_funnel_stage
      t.string :to_funnel_stage
      t.integer :trigger, default: 0, null: false
      t.string :trigger_details

      t.timestamps
    end

    add_index :status_changes, [ :volunteer_id, :created_at ]
  end
end
