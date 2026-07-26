class AddUniqueIndexToNjCountiesName < ActiveRecord::Migration[8.1]
  def change
    add_index :nj_counties, :name, unique: true
  end
end
