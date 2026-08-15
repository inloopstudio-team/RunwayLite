class RenameCanFetchUrlsToWebAccess < ActiveRecord::Migration[8.1]

  def change
    # libsql does not support rename_column; column already named :web_access in add_can_fetch_urls_to_chats
  end

end
