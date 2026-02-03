class CreateExternalSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :external_sync_logs do |t|
      t.references :volunteer, foreign_key: true
      t.integer :sync_type, default: 0, null: false
      t.integer :sync_direction, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.integer :records_processed
      t.text :error_message
      t.jsonb :payload_snapshot
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :external_sync_logs, :status
    add_index :external_sync_logs, :started_at
  end
end
