class TweakMoreColumnTypes < ActiveRecord::Migration[6.1]
  def up
    change_column :twitch_videos, :description, :text
  end


  def down
    # Reverting will fail if there's data in the DB, due to data exceeding the column size
    # change_column :twitch_videos, :description, :string
  end
end
