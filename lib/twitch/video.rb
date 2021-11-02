# frozen_string_literal: true

module Twitch
  # Represent a Twitch user
  class Video < ActiveRecord::Base
    belongs_to :twitch_user, class_name: 'Twitch::User'



    def ended_at
      started_at + duration
    end


    def contains_activity(activity)
      raise ArgumentError unless activity.is_a? Bungie::Activities::Activity

      (started_at <= activity.started_at) && (ended_at >= activity.ended_at)
    end


    def self.load_videos_for_user_id(user_id, twitch_user: nil)
      raise ArgumentError unless user_id

      begin
        results = Twitch::Api.instance.get_twitch_videos_for_user_id(user_id)
      rescue QueryError
        return []
      end
      return [] unless results&.size&.positive?

      results.map { |video_hash| create_or_update_from_hash(video_hash, twitch_user) }
    end


    def self.load_by_video_id(video_id, twitch_user: nil)
      raise ArgumentError unless video_id

      begin
        results = Twitch::Api.instance.get_twitch_video_for_video_id(video_id)
      rescue QueryError
        return []
      end
      return [] unless results&.dig('id')

      create_or_update_from_hash(results, twitch_user)
    end



    def self.create_or_update_from_hash(video_hash, twitch_user)
      return nil unless video_hash&.dig('id')

      twitch_user ||= Twitch::User.load_by_user_id(video_hash&.dig('user_id'))

      video = Twitch::Video.find_or_initialize_by(video_id: video_hash&.dig('id').to_i)

      video.twitch_user   = twitch_user
      video.stream_id     = video_hash&.dig('stream_id').to_i
      video.title         = video_hash&.dig('title')
      video.description   = video_hash&.dig('description')
      video.started_at    = Time.parse(video_hash&.dig('created_at')) if video_hash&.dig('created_at')
      video.published_at  = Time.parse(video_hash&.dig('published_at')) if video_hash&.dig('published_at')
      video.url           = video_hash&.dig('url')
      video.thumbnail_url = video_hash&.dig('thumbnail_url')
      video.viewable      = video_hash&.dig('viewable')
      video.view_count    = video_hash&.dig('view_count').to_i
      video.language      = video_hash&.dig('language')
      video.video_type    = video_hash&.dig('type')
      video.duration      = video_hash&.dig('duration').to_i

      # Sometimes the `title` and `description` fields contain weird characters the DB doesn't
      # like. If it gives us problems, save it again without those fields
      begin
        video.save
      rescue ActiveRecord::StatementInvalid
        video.title       = ''
        video.description = ''
        video.save
      end

      video
    end

  end
end

