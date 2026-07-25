class CreateNjCounties < ActiveRecord::Migration[8.1]
  def change
    create_table :nj_counties do |t|
      t.string :name

      t.timestamps
    end
  end
end
