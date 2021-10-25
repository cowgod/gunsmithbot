#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'


##### STILL TO DO:
# - Implement command to let users set `find_twitch_clips` field true or false
# - Implement regular process in bot to check for new, unreported match_clips, and report them in each configured channel (how do we handle this? Each user may want it in one or more locations. Same user might be in several discord servers and several slack servers)


Cowgod::Logger.log 'Reporting new clips...'

Bungie::Activities::Clip.pending_notification.each do |clip|
  # Build up a map of which included users we're going to report in each destination
  notification_destinations = {}

  clip&.activity&.players&.map(&:bungie_user)&.select(&:find_twitch_clips)&.each do |bungie_user|
    # Be sure we actually have config information about where to report their matches
    next unless CONFIG&.dig('twitch_clips', 'users', bungie_user.unique_name)


    %i[discord slack].each do |platform|
      next unless CONFIG&.dig('twitch_clips', 'users', bungie_user.unique_name, platform.to_s)

      CONFIG&.dig('twitch_clips', 'users', bungie_user.unique_name, platform.to_s)&.each do |webhook_url|
        notification_destinations[platform]                              ||= {}
        notification_destinations[platform][webhook_url]                 ||= {}
        notification_destinations[platform][webhook_url][bungie_user.id] = true
      end
    end
  end


  # Send a message to each destination we found
  if notification_destinations[:discord]
    notification_destinations[:discord].each do |webhook_url, bungie_users|
      Gunsmith::DiscordBot.notify_twitch_clip(
        clip:         clip,
        webhook_url:  webhook_url,
        bungie_users: bungie_users.keys.map { |id| Bungie::User.find_by(id: id) }
      )
    end
  end

  exit

  if notification_destinations[:slack]
    notification_destinations[:slack].each do |webhook_url, bungie_users|
      pp webhook_url
      pp bungie_users.keys
      # Slack::Bot.notify_twitch_clip(clip: clip,)
    end
  end


  exit ######DEBUG


  # Mark clip as reported
  clip.notified_at = Time.now
  clip.save
end

Cowgod::Logger.log 'Done reporting new clips.'
