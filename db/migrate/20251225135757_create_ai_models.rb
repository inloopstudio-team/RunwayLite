class CreateAiModels < ActiveRecord::Migration[8.1]

  def change
    # Create the ai_models table for RubyLLM 1.9+
    create_table :ai_models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.text :modalities, default: '{}'
      t.text :capabilities, default: '[]'
      t.text :pricing, default: '{}'
      t.text :metadata, default: '{}'
      t.timestamps

      t.index [ :provider, :model_id ], unique: true
      t.index :provider
      t.index :family
    end

    # SQLite 3.25+ supports RENAME COLUMN; use raw SQL instead of rename_column
    execute "ALTER TABLE chats RENAME COLUMN model_id TO model_id_string"
    execute "ALTER TABLE messages RENAME COLUMN model_id TO model_id_string"

    # Add foreign key references to ai_models
    add_reference :chats, :ai_model, foreign_key: true
    add_reference :messages, :ai_model, foreign_key: true
  end

end
