# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class User < ActiveRecord::Base
    has_many :memberships, class_name: 'Bungie::Membership', foreign_key: 'bungie_user_id'
    has_many :slack_users, class_name: 'Slack::User', foreign_key: 'bungie_user_id'
    has_many :discord_users, class_name: 'Discord::User', foreign_key: 'bungie_user_id'
    belongs_to :twitch_user, class_name: 'Twitch::User'



    def bungie_name
      "#{bungie_display_name}##{bungie_display_name_code}"
    end


    def load_twitch_user
      self.twitch_user = Twitch::User.load_by_display_name(twitch_display_name)
      save
      twitch_user
    end


    def guess_twitch_user
      return twitch_user if twitch_user

      [unique_name, display_name, normalized_name, steam_display_name, stadia_display_name, bungie_display_name].each do |field|
        next unless field&.match /t\.?tv/i

        potential_twitch_names = []

        potential_twitch_name = field.sub(/(#\d+)$/, '').sub(%r{[- .:/\\]*t\.?tv[- .:/\\]*}i, '')

        potential_twitch_names << potential_twitch_name
        potential_twitch_names << potential_twitch_name.sub(/_+$/, '') if potential_twitch_name.match(/_+$/)

        next unless potential_twitch_names.size&.positive?

        potential_twitch_names.each do |potential_twitch_name|
          # See if a user exists with this display name
          twitch_user = Twitch::User.load_by_display_name(potential_twitch_name)
          next unless twitch_user

          # See if this user has any saved videos. Ideally, we could check if any of the saved videos were associated
          # with the Destiny 2 game ID, the Twitch API doesn't provide any information about the game that's contained
          # in each video. So we'll just check to see if there are any saved VODs at all. If not, then we can't find any
          # clips anyway, so it's not worth taking the gamble of linking to this guessed twitch account
          # TODO -- we could get more specific, taking the activity ID as an argument, and seeing if they
          # were streaming Destiny 2 at the time the activity took place. But for now we'll see if this is
          # good enough
          twitch_videos = Twitch::Video.load_videos_for_user_id(
            twitch_user.user_id,
            twitch_user: twitch_user
          )
          next unless twitch_videos&.size&.positive?

          # We found a Twitch user with this name, and they have saved VODs, so we will guess it's them
          self.twitch_user         = twitch_user
          self.twitch_display_name = twitch_user.display_name
          save

          return twitch_user
        end
      end

      nil
    end



    def self.load_by_destiny_membership_id(membership_id, find_twitch_clips_if_new: nil)
      return nil unless membership_id

      # Load the memberships for this platform membership, which will include info about the Bungie membership ID
      results = Bungie::Api.instance.get_memberships_for_membership_id(membership_id)
      return nil unless results&.dig('bungieNetUser')&.dig('membershipId')

      # Load the Bungie user for this Bungie membership ID
      load_by_bungie_membership_id(results&.dig('bungieNetUser')&.dig('membershipId'), find_twitch_clips_if_new: find_twitch_clips_if_new)
    end


    def self.load_by_bungie_membership_id(membership_id, find_twitch_clips_if_new: nil)
      return nil unless membership_id

      user_hash = Bungie::Api.instance.get_bungie_user_for_membership_id(membership_id)
      return nil unless user_hash&.dig('membershipId')

      create_or_update_from_hash(user_hash, find_twitch_clips_if_new: find_twitch_clips_if_new)
    end


    def self.create_or_update_from_hash(user_hash, find_twitch_clips_if_new: nil)
      user = User.find_or_initialize_by(membership_id: user_hash&.dig('membershipId'))

      user.unique_name              = user_hash&.dig('uniqueName')
      user.display_name             = user_hash&.dig('displayName')
      user.psn_display_name         = user_hash&.dig('psn_display_name')
      user.xbox_display_name        = user_hash&.dig('xbox_display_name')
      user.blizzard_display_name    = user_hash&.dig('blizzardDisplayName')
      user.steam_display_name       = user_hash&.dig('steamDisplayName')
      user.stadia_display_name      = user_hash&.dig('stadiaDisplayName')
      user.twitch_display_name      = user_hash&.dig('twitchDisplayName') if user_hash&.dig('twitchDisplayName')
      user.bungie_display_name      = user_hash&.dig('cachedBungieGlobalDisplayName')
      user.bungie_display_name_code = user_hash&.dig('cachedBungieGlobalDisplayNameCode')
      user.about                    = user_hash&.dig('about')
      user.first_accessed_at        = Time.parse(user_hash&.dig('firstAccess')) if user_hash&.dig('firstAccess')
      user.last_updated_at          = Time.parse(user_hash&.dig('lastUpdate')) if user_hash&.dig('lastUpdate')

      user.find_twitch_clips        = true if find_twitch_clips_if_new && user.new_record?


      # Sometimes the `about` field contains weird characters the DB doesn't
      # like. If it gives us problems, save it again without that field
      begin
        user.save
      rescue ActiveRecord::StatementInvalid
        user.about = ''
        user.save
      end

      user
    end
  end
end
