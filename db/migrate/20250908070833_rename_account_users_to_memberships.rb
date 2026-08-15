class RenameAccountUsersToMemberships < ActiveRecord::Migration[8.0]

  def change
    execute "ALTER TABLE account_users RENAME TO memberships" if table_exists?(:account_users)
  end

end
