# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class User < ActiveRecord::Base
    has_many :memberships, class_name: 'Bungie::Membership', foreign_key: 'bungie_user_id'
    has_many :slack_users, class_name: 'Slack::User'
    has_many :discord_users, class_name: 'Discord::User'
    belongs_to :twitch_user, class_name: 'Twitch::User'



    def bungie_name
      "#{bungie_display_name}##{bungie_display_name_code}"
    end



    def self.load_by_destiny_membership_id(membership_id)
      return nil unless membership_id

      # Load the memberships for this platform membership, which will include info about the Bungie membership ID
      results = Bungie::Api.instance.get_memberships_for_membership_id(membership_id)
      raise QueryError, "Couldn't find the requested user." unless results&.dig('bungieNetUser')&.dig('membershipId')

      # Load the Bungie user for this Bungie membership ID
      load_by_bungie_membership_id(results&.dig('bungieNetUser')&.dig('membershipId'))
    end


    def self.load_by_bungie_membership_id(membership_id)
      return nil unless membership_id

      user_hash = Bungie::Api.instance.get_bungie_user_for_membership_id(membership_id)
      raise QueryError, "Couldn't find the requested user." unless user_hash&.dig('membershipId')

      create_or_update_from_hash(user_hash)
    end


    def self.create_or_update_from_hash(user_hash)
      user = User.find_or_initialize_by(membership_id: user_hash&.dig('membershipId'))

      user.unique_name              = user_hash&.dig('uniqueName')
      user.display_name             = user_hash&.dig('displayName')
      user.psn_display_name         = user_hash&.dig('psn_display_name')
      user.xbox_display_name        = user_hash&.dig('xbox_display_name')
      user.blizzard_display_name    = user_hash&.dig('blizzardDisplayName')
      user.steam_display_name       = user_hash&.dig('steamDisplayName')
      user.stadia_display_name      = user_hash&.dig('stadiaDisplayName')
      user.twitch_display_name      = user_hash&.dig('twitchDisplayName')
      user.bungie_display_name      = user_hash&.dig('cachedBungieGlobalDisplayName')
      user.bungie_display_name_code = user_hash&.dig('cachedBungieGlobalDisplayNameCode')
      user.about                    = user_hash&.dig('about')
      user.first_accessed_at        = DateTime.parse(user_hash&.dig('firstAccess'))
      user.last_updated_at          = DateTime.parse(user_hash&.dig('lastUpdate'))

      user.save

      user
    end
  end
end
