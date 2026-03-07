class AddModelToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :model, :string, null: false, default: "htdemucs"
  end
end
