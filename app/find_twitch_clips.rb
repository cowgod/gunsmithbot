#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../environment'

sleep_interval = $config&.dig('twitch_clips', 'find_interval').presence || 60

loop do
	Cowgod::Logger.log 'Importing new activities...'

	Bungie::User.where(find_twitch_clips: true)&.each do |bungie_user|
		### TODO -- move this logic into Bungie::User
		bungie_user&.memberships&.each do |membership|
			membership.load_characters&.values&.each do |character|
				character.load_unscanned_activities(mode: Bungie::Api::ACTIVITY_MODES[:all_pvp])&.each_value do |activity|
					activity.players&.with_twitch_account&.each do |player|
						twitch_user = player.bungie_user&.load_twitch_user || player.bungie_user&.guess_twitch_user
						next unless twitch_user

						twitch_user.load_videos.each do |video|
							next unless video.contains_activity(activity)

							log_msg = "Found clip for user '#{bungie_user.bungie_name}' "
							log_msg += "from Twitch user #{twitch_user.display_name} "
							log_msg += "on #{activity.started_at}"
							Cowgod::Logger.log log_msg

							Bungie::Activities::Clip.find_or_create_by(activity: activity, twitch_video: video)
						end
					end

					# Mark activity as scanned
					activity.scanned_at = Time.now
					activity.save
				rescue SocketError, Timeout::Error => e
					Cowgod::Logger.log "Error while scanning activity #{activity.id}, skipping,... (#{e.message})"
				end
			end
		end
	end

	Cowgod::Logger.log "Done importing new activities. Sleeping #{sleep_interval} secs..."

	sleep sleep_interval
end
