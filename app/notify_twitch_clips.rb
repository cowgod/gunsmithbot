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

  ### TODO -- rework this to just configure webhooks per server instead of per user
  #
  clip&.activity&.players&.map(&:bungie_user)&.select(&:find_twitch_clips)&.each do |bungie_user|
    # Be sure we actually have config information about where to report their matches
    next unless CONFIG&.dig('twitch_clips', 'users', bungie_user.unique_name)


    %i[discord slack].each do |platform|
      next unless CONFIG&.dig('twitch_clips', 'users', bungie_user.unique_name, platform.to_s)

      CONFIG&.dig('twitch_clips', 'users', bungie_user.unique_name, platform.to_s)&.each do |webhook_url|
        notification_destinations[platform]              ||= {}
        notification_destinations[platform][webhook_url] = true
      end
    end
  end


  # Send a message to each destination we found
  notification_destinations[:discord]&.each_key do |webhook_url|
    Gunsmith::DiscordBot.notify_twitch_clip(
      clip:        clip,
      webhook_url: webhook_url,
    )
  end


  notification_destinations[:slack]&.each_key do |webhook_url|
    ##### TODO
    # Gunsmith::SlackBot.notify_twitch_clip(
    #   clip:        clip,
    #   webhook_url: webhook_url,
    # )
  end


  # Mark clip as reported
  clip.notified_at = Time.now
  clip.save
end

Cowgod::Logger.log 'Done reporting new clips.'
