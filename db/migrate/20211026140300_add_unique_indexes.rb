class AddUniqueIndexes < ActiveRecord::Migration[6.1]
  def change
    add_index :bungie_activities, %i[instance_id], unique: true
    add_index :bungie_activity_clips, %i[bungie_activity_id twitch_video_id], unique: true, name: :idx__bng_act_clips__activity_id__twitch_video_id
    add_index :bungie_activity_players, %i[bungie_activity_id bungie_character_id], unique: true, name: :idx__bng_act_players__activity_id__character_id
    add_index :bungie_activity_teams, %i[bungie_activity_id team_id], unique: true, name: :idx__bng_act_teams__activity_id__team_id
    add_index :twitch_users, %i[user_id], unique: true
    add_index :twitch_videos, %i[video_id], unique: true
  end
end
