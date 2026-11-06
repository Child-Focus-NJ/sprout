class AddEmailDetailsToCommunications < ActiveRecord::Migration[8.1]
  def change
    add_column :communications, :email_to, :string
    add_column :communications, :purpose, :string
  end
end
