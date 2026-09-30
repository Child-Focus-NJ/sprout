class CreateSignInLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address

      t.timestamps
    end

    add_index :sign_in_logs, :created_at
  end
end
