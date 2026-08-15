class RenameThinkingToThinkingText < ActiveRecord::Migration[8.1]

  def up
    add_column :messages, :thinking_text, :text unless column_exists?(:messages, :thinking_text)
    execute "UPDATE messages SET thinking_text = thinking WHERE thinking IS NOT NULL"
    remove_column :messages, :thinking if column_exists?(:messages, :thinking)
    add_column :messages, :thinking_tokens, :integer unless column_exists?(:messages, :thinking_tokens)
  end

  def down
    add_column :messages, :thinking, :text unless column_exists?(:messages, :thinking)
    execute "UPDATE messages SET thinking = thinking_text WHERE thinking_text IS NOT NULL"
    remove_column :messages, :thinking_text if column_exists?(:messages, :thinking_text)
    remove_column :messages, :thinking_tokens if column_exists?(:messages, :thinking_tokens)
  end

end
