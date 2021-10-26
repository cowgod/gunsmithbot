class AddFieldsToPgcr < ActiveRecord::Migration[6.1]
  def change
    change_table :bungie_activity_players do |t|
      t.integer :kills, null: false, after: :bungie_character_id
      t.integer :assists, null: false, after: :kills
      t.integer :deaths, null: false, after: :assists
    end
  end
end
