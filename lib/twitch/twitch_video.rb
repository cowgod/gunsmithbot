# frozen_string_literal: true

module Twitch
  # Represent a Twitch user
  class TwitchVideo < ActiveRecord::Base
    belongs_to :twitch_user


    def self.load_videos_for_user_id(user_id, twitch_user: nil)
      return nil unless user_id

      results = Twitch::Api.instance.get_twitch_videos_for_user_id(user_id)
      raise QueryError, "Couldn't find the requested videos." unless results&.size&.positive?

      results.map { |video_hash| create_or_update_from_hash(video_hash, twitch_user) }
    end


    def self.load_by_video_id(video_id, twitch_user: nil)
      return nil unless video_id

      results = Twitch::Api.instance.get_twitch_video_for_video_id(video_id)
      raise QueryError, "Couldn't find the requested video." unless results&.dig('id')

      create_or_update_from_hash(results, twitch_user)
    end



    def self.create_or_update_from_hash(video_hash, twitch_user)
      return nil unless video_hash&.dig('id')

      twitch_user ||= Twitch::TwitchUser.load_by_user_id(results&.dig('user_id'))

      video = Twitch::TwitchVideo.find_or_initialize_by(twitch_user: twitch_user, video_id: video_hash&.dig('id'))

      video.video_id      = video_hash&.dig('id').to_i
      video.stream_id     = video_hash&.dig('stream_id').to_i
      video.title         = video_hash&.dig('title')
      video.description   = video_hash&.dig('description')
      video.started_at    = DateTime.parse(video_hash&.dig('created_at'))
      video.published_at  = DateTime.parse(video_hash&.dig('published_at'))
      video.url           = video_hash&.dig('url')
      video.thumbnail_url = video_hash&.dig('thumbnail_url')
      video.viewable      = video_hash&.dig('viewable')
      video.view_count    = video_hash&.dig('view_count').to_i
      video.language      = video_hash&.dig('language')
      video.type          = video_hash&.dig('type')
      video.duration      = video_hash&.dig('duration').to_i

      video.save

      video
    end

  end
end

