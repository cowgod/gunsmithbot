#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


##### STILL TO DO:
# - Implement command to let users set `find_twitch_streams` field true or false
# - Implement regular process in bot to check for new, unreported match_clips, and report them in each configured channel (how do we handle this? Each user may want it in one or more locations. Same user might be in several discord servers and several slack servers)

Bungie::User.where(find_twitch_streams: true)&.each do |bungie_user|
  bungie_user&.memberships&.each do |membership|
    membership.load_characters&.values&.each do |character|
      # character.load_unscanned_activities(mode: Bungie::Api::ACTIVITY_MODES[:all_pvp])&.each_value do |activity|
      character.load_unscanned_activities(mode: Bungie::Api::ACTIVITY_MODES[:trials_of_osiris])&.each_value do |activity|

        activity.players&.with_twitch_account&.each do |player|
          twitch_user = player.bungie_user&.load_twitch_user
          next unless twitch_user

          twitch_user.load_videos.each do |video|
            next unless video.contains_activity(activity)

            log_msg = "Found clip for user '#{bungie_user.bungie_name}' "
            log_msg += "from Twitch user #{twitch_user.display_name} "
            # log_msg += "in activity #{Bungie::Manifest.instance.lookup_activity(activity.director_activity_hash)} "
            # log_msg += "on #{Bungie::Manifest.instance.lookup_activity(clip.activity.reference_id)} "
            log_msg += "on #{activity.started_at}"
            pp log_msg

            Bungie::Activities::Clip.find_or_create_by(activity: activity, twitch_video: video)
          end


          # Mark activity as scanned
          activity.scanned_at = Time.now
          activity.save
        end
      end
    end
  end
end

pp "Done."


# For clips pending reporting
#   Get list of all tracked users contained in clip
#   Report in each channel (how do we handle the fact that one user might want us to report in more than one place, but not everyone in the clip might be present in each server?)


