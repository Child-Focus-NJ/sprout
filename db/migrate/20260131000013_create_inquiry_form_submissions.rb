class CreateInquiryFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiry_form_submissions do |t|
      t.references :volunteer, foreign_key: true
      t.jsonb :raw_data
      t.string :source
      t.boolean :processed, default: false, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :inquiry_form_submissions, :processed
    add_index :inquiry_form_submissions, :source
  end
end
