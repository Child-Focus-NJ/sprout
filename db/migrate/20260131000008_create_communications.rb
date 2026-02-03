class CreateCommunications < ActiveRecord::Migration[8.1]
  def change
    create_table :communications do |t|
      t.references :volunteer, null: false, foreign_key: true
      t.references :communication_template, foreign_key: true
      t.references :sent_by_user, foreign_key: { to_table: :users }
      t.integer :communication_type, default: 0, null: false
      t.string :subject
      t.text :body
      t.integer :status, default: 0, null: false
      t.datetime :sent_at
      t.string :external_id

      t.timestamps
    end

    add_index :communications, :sent_at
    add_index :communications, :status
  end
end
