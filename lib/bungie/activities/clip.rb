# frozen_string_literal: true

module Bungie
  module Activities
    # Represent a Twitch clip of a Destiny activity
    class Clip < ActiveRecord::Base
      belongs_to :activity, foreign_key: :bungie_activity_id
      belongs_to :twitch_video, class_name: 'Twitch::Video'


      def offset
        (activity.started_at - twitch_video.started_at).to_i.clamp(0, 999_999_999_999)
      end


      def url
        return nil unless activity && twitch_video

        "https://www.twitch.tv/videos/#{twitch_video.video_id.to_s.uri_encode}?t=#{offset.to_offset_string}"
      end
    end
  end
end
