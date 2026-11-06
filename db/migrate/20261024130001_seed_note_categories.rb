class SeedNoteCategories < ActiveRecord::Migration[8.1]
  CATEGORIES = {
    "note" => "Note",
    "attended_info_session" => "Attended Info Session",
    "no_show" => "No-show",
    "rescheduled" => "Rescheduled",
    "cancelled" => "Cancelled",
    "deactivated" => "Deactivated"
  }.freeze

  def up
    CATEGORIES.each do |key, name|
      NoteCategory.find_or_create_by!(key: key) { |category| category.name = name }
    end
    Feature.find_or_create_by!(key: "note_categories") do |feature|
      feature.admin_only = true
      feature.description = "Managing note category options"
    end

    execute <<~SQL
      UPDATE notes SET note_category_id = (SELECT id FROM note_categories WHERE key = 'note')
      WHERE note_category_id IS NULL
    SQL
    change_column_null :notes, :note_category_id, false
  end

  def down
    change_column_null :notes, :note_category_id, true
  end
end
