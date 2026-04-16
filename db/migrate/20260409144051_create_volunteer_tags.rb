class CreateVolunteerTags < ActiveRecord::Migration[8.1]
  def change
    create_table :volunteer_tags do |t|
      t.string :title

      t.timestamps
    end
  end
end
