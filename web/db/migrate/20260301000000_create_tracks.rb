class CreateTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracks do |t|
      t.string :name,     null: false
      t.string :filename, null: false
      t.string :status,   default: "pending"

      t.timestamps
    end
  end
end
