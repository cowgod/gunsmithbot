class ChangeColumnSizes < ActiveRecord::Migration[6.1]
  def up
    change_column :twitch_users, :description, :text

    rename_column :bungie_users, :find_twitch_streams, :find_twitch_clips

    rename_column :bungie_activity_clips, :reported_at, :notified_at
  end


  def down
    # change_column :twitch_users, :description, :string

    rename_column :bungie_users, :find_twitch_clips, :find_twitch_streams

    rename_column :bungie_activity_clips, :notified_at, :reported_at
  end
end
