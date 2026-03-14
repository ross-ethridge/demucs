class AddUserToTracks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tracks, :user, null: true, foreign_key: true
  end
end
