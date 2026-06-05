class AddModerationToMessages < ActiveRecord::Migration[8.1]

  def change
    add_column :messages, :moderation_scores, :json
    add_column :messages, :moderated_at, :datetime
  end

end
