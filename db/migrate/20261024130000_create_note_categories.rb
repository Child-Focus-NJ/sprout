class CreateNoteCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :note_categories do |t|
      t.string :name, null: false
      t.string :key

      t.timestamps
    end

    add_index :note_categories, :name, unique: true
    add_index :note_categories, :key, unique: true

    add_reference :notes, :note_category, foreign_key: true
  end
end
