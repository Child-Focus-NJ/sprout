# frozen_string_literal: true

class RemoveVmsSyncArtifacts < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :external_sync_logs, :volunteers if foreign_key_exists?(:external_sync_logs, :volunteers)
    drop_table :external_sync_logs, if_exists: true

    remove_index :volunteers, :external_id if index_exists?(:volunteers, :external_id)
    remove_column :volunteers, :external_id, :string if column_exists?(:volunteers, :external_id)
    remove_column :volunteers, :external_synced_at, :datetime if column_exists?(:volunteers, :external_synced_at)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
