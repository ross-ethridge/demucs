class RequireUserOnTracks < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM tracks WHERE user_id IS NULL"
    change_column_null :tracks, :user_id, false
  end

  def down
    change_column_null :tracks, :user_id, true
  end
end
