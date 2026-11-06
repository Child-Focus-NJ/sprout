class AddEditedAtToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :edited_at, :datetime
  end
end
