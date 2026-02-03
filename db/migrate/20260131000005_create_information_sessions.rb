class CreateInformationSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :information_sessions do |t|
      t.string :name
      t.datetime :scheduled_at, null: false
      t.string :location
      t.integer :capacity
      t.integer :session_type, default: 0, null: false
      t.text :notes
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :information_sessions, :scheduled_at
    add_index :information_sessions, :active
  end
end
