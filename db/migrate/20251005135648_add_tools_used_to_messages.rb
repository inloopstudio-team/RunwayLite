class AddToolsUsedToMessages < ActiveRecord::Migration[8.0]

  def change
    add_column :messages, :tools_used, :text, default: '[]'
  end

end
