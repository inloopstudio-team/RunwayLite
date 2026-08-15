class RenameChangesToDataInAuditLogs < ActiveRecord::Migration[8.0]

  def change
    # libsql does not support rename_column; column already named :data in create_audit_logs
  end

end
