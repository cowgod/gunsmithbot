# frozen_string_literal: true

module Bungie
  module Activities
    # Represent a Twitch clip of a Destiny activity
    class Clip < ActiveRecord::Base
      belongs_to :activity, foreign_key: :bungie_activity_id
      belongs_to :twitch_video, class_name: 'Twitch::Video'


      scope :pending_announcement, -> { joins(:activity).where(announced_at: nil).order('bungie_activities.started_at ASC') }


      def offset
        (activity.started_at - twitch_video.started_at).to_i.clamp(0, 999_999_999_999)
      end


      def url
        return nil unless activity && twitch_video

        "https://www.twitch.tv/videos/#{twitch_video.video_id.to_s.uri_encode}?t=#{offset.to_offset_string}"
      end


      def tracked_players
        activity&.tracked_players
      end


      def announce
        # While we get up and running, only announce clips for the last few weeks
        unless activity&.started_at && activity.started_at > Time.new(2021, 10, 1)
          # Mark clip as reported
          self.announced_at = Time.now
          save
          return true
        end


        # Build up a map of which destinations we'll be reporting this clip in
        webhook_urls = {
          discord: {},
          slack:   {}
        }

        tracked_players&.map do |player|
          # Gather applicable Discord webhooks
          # next unless player&.bungie_user&.discord_users.respond_to? :each

          player&.bungie_user&.discord_users&.each do |discord_user|
            discord_user.announcement_servers.each do |server|
              next unless $config&.dig('twitch_clips', 'webhooks', 'discord', server.server_id)

              $config&.dig('twitch_clips', 'webhooks', 'discord', server.server_id)&.each do |webhook_url|
                webhook_urls[:discord][webhook_url] = true
              end
            end
          end


          ### TODO: gather applicable Slack webhooks (check the teams associated with the slack user)
        end


        # Send a message to each destination we found
        webhook_urls[:discord]&.each_key do |webhook_url|
          Gunsmith::DiscordBot.announce_twitch_clip(
            clip:        self,
            webhook_url: webhook_url
          )
        end


        ##### TODO
        # notification_destinations[:slack]&.each_key do |webhook_url|
        #   # Gunsmith::SlackBot.announce_twitch_clip(
        #   #   clip:        clip,
        #   #   webhook_url: webhook_url,
        #   # )
        # end


        # Mark clip as reported
        self.announced_at = Time.now
        save
      end

    end
  end
end
