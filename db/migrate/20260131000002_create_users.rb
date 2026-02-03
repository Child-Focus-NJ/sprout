class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.integer :role, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
