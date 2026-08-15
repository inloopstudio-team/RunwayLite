class CreateChats < ActiveRecord::Migration[8.0]

  def change
    create_table :chats do |t|
      t.belongs_to :account, null: false, foreign_key: true
      t.string :title
      t.string :model_id_string, null: false, default: 'openrouter/auto'
      t.timestamps
    end

    add_index :chats, [ :account_id, :created_at ]
  end

end
