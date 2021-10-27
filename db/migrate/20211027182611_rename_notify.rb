class RenameNotify < ActiveRecord::Migration[6.1]
  def change
    rename_column :bungie_activity_clips, :notified_at, :announced_at
    rename_column :discord_memberships, :notify_twitch_clips, :announce_twitch_clips
  end
end
