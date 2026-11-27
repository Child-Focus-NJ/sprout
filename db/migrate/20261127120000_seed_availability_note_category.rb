class SeedAvailabilityNoteCategory < ActiveRecord::Migration[8.1]
  NAME = "Availability".freeze

  def up
    NoteCategory.find_or_create_by!(name: NAME)
  end

  def down
    NoteCategory.find_by(name: NAME, key: nil)&.destroy!
  end
end
