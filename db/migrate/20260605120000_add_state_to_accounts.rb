class AddStateToAccounts < ActiveRecord::Migration[8.1]

  def up
    add_column :accounts, :state, :string, null: false, default: "active"
    add_index :accounts, :state

    # Backfill: accounts with disabled_at → "disabled"
    execute <<~SQL
      UPDATE accounts SET state = 'disabled' WHERE disabled_at IS NOT NULL
    SQL
  end

  def down
    remove_column :accounts, :state
  end

end
