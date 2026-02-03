class CreateSystemSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :system_settings do |t|
      t.string :key, null: false
      t.text :value
      t.integer :value_type, default: 0, null: false
      t.string :description
      t.references :updated_by_user, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :system_settings, :key, unique: true
  end
end
