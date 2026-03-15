class AddStripeSessionIdToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :stripe_session_id, :string
    add_index :tracks, :stripe_session_id, unique: true
  end
end
