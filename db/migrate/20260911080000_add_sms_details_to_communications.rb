class AddSmsDetailsToCommunications < ActiveRecord::Migration[8.1]
  def change
    add_column :communications, :sms_to, :string
    add_column :communications, :sms_consent, :string
    add_column :communications, :error_message, :text
  end
end
