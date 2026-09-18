class DefaultUsersToUserRole < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE users SET role = 1 WHERE role = 2"
    change_column_default :users, :role, from: 0, to: 1
  end

  def down
    change_column_default :users, :role, from: 1, to: 0
  end
end
