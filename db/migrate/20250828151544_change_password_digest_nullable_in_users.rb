class ChangePasswordDigestNullableInUsers < ActiveRecord::Migration[8.0]

  def change
    # libsql adapter does not support change_column_null; column is nullable from create_users
  end

end
