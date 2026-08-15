class GetRidOfDefaultAccountId < ActiveRecord::Migration[8.0]

  def change
    execute "DROP INDEX IF EXISTS index_users_on_default_account_id"
    remove_column :users, :default_account_id
  end

end
