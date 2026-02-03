class CreateReferralSources < ActiveRecord::Migration[8.1]
  def change
    create_table :referral_sources do |t|
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :referral_sources, :name, unique: true
  end
end
