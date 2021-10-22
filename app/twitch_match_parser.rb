#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


##### STILL TO DO:
# - Implement command to let users set `find_twitch_streams` field true or false
# - Implement regular process in bot to check for new, unreported match_clips, and report them in each configured channel (how do we handle this? Each user may want it in one or more locations. Same user might be in several discord servers and several slack servers)

Bungie::User.where(find_twitch_streams: true)&.each do |bungie_user|
  bungie_user&.memberships&.each do |membership|
    membership&.load_characters&.values&.each do |character|
      character&.load_unscanned_activities(mode: Bungie::Api::ACTIVITY_MODES[:all_pvp])&.each_value do |activity|
        activity.players&.with_twitch_account&.each do |player|

          #     Load the user's bungie account
          #     Load the user's twitch account
          #     Load the user's twitch videos
          #     Look for a twitch video containing the time window of the PGCR
          #     If found, save it to match_clips table

        end
      end
    end
  end


  # videos = bungie_user&.twitch_user&.load_videos


  # # Load twitch account
  # twitch_account = Twitch::Api.instance.get_twitch_user_for_display_name(bungie_membership.bungie_user.twitch_display_name)
  # twitch_videos  = Twitch::Api.instance.get_twitch_videos_for_user_id(twitch_account['id'])


  # pp videos
end


