class AddCanFetchUrlsToChats < ActiveRecord::Migration[8.0]

  def change
    add_column :chats, :web_access, :boolean, default: false, null: false
    add_index :chats, :web_access
  end

end
