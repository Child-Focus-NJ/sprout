class CreateDuplicateDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :duplicate_dismissals do |t|
      t.references :volunteer, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :other_volunteer, null: false, foreign_key: { to_table: :volunteers, on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :duplicate_dismissals, [ :volunteer_id, :other_volunteer_id ], unique: true,
                                                                             name: "index_duplicate_dismissals_on_pair"
    add_check_constraint :duplicate_dismissals, "volunteer_id < other_volunteer_id", name: "duplicate_dismissals_lowest_id_first"
  end
end
