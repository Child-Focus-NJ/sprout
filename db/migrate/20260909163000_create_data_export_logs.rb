class CreateDataExportLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :data_export_logs do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.integer :trigger, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.string :filename
      t.bigint :byte_size
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :data_export_logs, :status
    add_index :data_export_logs, :created_at
  end
end
