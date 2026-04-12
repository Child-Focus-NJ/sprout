# frozen_string_literal: true

class AddCreatedByUserToInformationSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :information_sessions, :created_by_user, foreign_key: { to_table: :users }, null: true
  end
end
