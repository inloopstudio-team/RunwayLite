class AddStateToMemberships < ActiveRecord::Migration[8.1]

  def up
    add_column :memberships, :state, :string, null: false, default: "pending"
    add_index :memberships, :state

    # Backfill: memberships with confirmed_at → "active"
    execute <<~SQL
      UPDATE memberships SET state = 'active' WHERE confirmed_at IS NOT NULL
    SQL
  end

  def down
    remove_column :memberships, :state
  end

end
