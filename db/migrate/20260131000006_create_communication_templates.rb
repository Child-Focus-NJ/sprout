class CreateCommunicationTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :communication_templates do |t|
      t.string :name, null: false
      t.integer :template_type, default: 0, null: false
      t.integer :funnel_stage, null: false
      t.integer :trigger_type, default: 0, null: false
      t.integer :interval_weeks
      t.string :subject
      t.text :body, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :communication_templates, [ :funnel_stage, :trigger_type ]
    add_index :communication_templates, :active
  end
end
