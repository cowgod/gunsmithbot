class TweakColumnTypes < ActiveRecord::Migration[6.1]
  def up
    change_column :bungie_characters, :character_id, :bigint
    rename_column :bungie_characters, :membership_id, :bungie_membership_id

    change_column :twitch_users, :user_id, :bigint

    change_column :twitch_videos, :video_id, :bigint
    change_column :twitch_videos, :stream_id, :bigint
    rename_column :twitch_videos, :type, :video_type
  end


  def down
    change_column :bungie_characters, :character_id, :string
    rename_column :bungie_characters, :bungie_membership_id, :membership_id

    change_column :twitch_users, :user_id, :string

    change_column :twitch_videos, :video_id, :string
    change_column :twitch_videos, :stream_id, :string
    rename_column :twitch_videos, :video_type, :type
  end
end
