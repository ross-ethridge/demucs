class AddProgressToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :progress, :integer, default: 0, null: false
  end
end
