class AddZoomLinkToInformationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :information_sessions, :zoom_link, :text
  end
end
