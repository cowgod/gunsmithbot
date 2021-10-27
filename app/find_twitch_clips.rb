#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


Cowgod::Logger.log 'Importing new activities...'

Bungie::User.where(find_twitch_clips: true)&.each do |bungie_user|
  ### TODO -- move this logic into Bungie::User
  bungie_user&.memberships&.each do |membership|
    membership.load_characters&.values&.each do |character|
      character.load_unscanned_activities(mode: Bungie::Api::ACTIVITY_MODES[:all_pvp])&.each_value do |activity|
        # character.load_unscanned_activities(mode: Bungie::Api::ACTIVITY_MODES[:trials_of_osiris])&.each_value do |activity|

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

Cowgod::Logger.log 'Done importing new activities.'

