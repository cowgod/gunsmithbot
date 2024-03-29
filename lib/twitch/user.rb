# frozen_string_literal: true

module Twitch
  # Represent a Twitch user
  class User < ActiveRecord::Base
    has_one :bungie_user, class_name: 'Bungie::User', foreign_key: 'twitch_user_id'
    has_many :videos



    def load_videos
      Twitch::Video.load_videos_for_user_id(user_id, twitch_user: self)
    end


    def self.load_by_user_id(user_id)
      raise ArgumentError unless user_id

      begin
        results = Twitch::Api.instance.get_twitch_user_for_user_id(user_id)
      rescue QueryError
        return nil
      end
      return nil unless results&.dig('id')


      create_or_update_from_hash(results)
    end


    def self.load_by_display_name(display_name)
      raise ArgumentError unless display_name

      begin
        results = Twitch::Api.instance.get_twitch_user_for_display_name(display_name)
      rescue QueryError
        return nil
      end
      return nil unless results&.dig('id')


      create_or_update_from_hash(results)
    end


    def self.create_or_update_from_hash(user_hash)
      return nil unless user_hash&.dig('id')


      user = find_or_initialize_by(user_id: user_hash&.dig('id').to_i)

      user.login_name         = user_hash&.dig('login')
      user.display_name       = user_hash&.dig('display_name')
      user.broadcaster_type   = user_hash&.dig('broadcaster_type')
      user.description        = user_hash&.dig('description')
      user.profile_image_url  = user_hash&.dig('profile_image_url')
      user.offline_image_url  = user_hash&.dig('offline_image_url')
      user.view_count         = user_hash&.dig('view_count').to_i
      user.channel_created_at = user_hash&.dig('created_at')

      # Sometimes the `description` field contains weird characters the DB doesn't
      # like. If it gives us problems, save it again without that field
      begin
        user.save
      rescue ActiveRecord::StatementInvalid
        user.description = ''
        user.save
      end

      user
    end
  end
end

