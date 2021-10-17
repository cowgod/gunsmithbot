# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class BungieUser < ActiveRecord::Base
    has_many :bungie_memberships



    def bungie_name
      "#{bungie_display_name}##{bungie_display_name_code}"
    end



    def self.search_user_by_platform_membership_id(membership_id)
      nil unless membership_id

      # Load the memberships for this platform membership, which will include info about the Bungie membership ID
      results = Bungie::Api.instance.get_memberships_for_membership_id(membership_id)
      raise QueryError, "Couldn't find the requested user." unless results&.dig('bungieNetUser')&.dig('membershipId')

      # Load the Bungie user for this Bungie membership ID
      search_user_by_bungie_membership_id(results&.dig('bungieNetUser')&.dig('membershipId'))
    end


    def self.search_user_by_bungie_membership_id(membership_id)
      nil unless membership_id

      results = Bungie::Api.instance.get_bungie_user_for_membership_id(membership_id)
      raise QueryError, "Couldn't find the requested user." unless results&.dig('membershipId')

      user = BungieUser.find_or_create_by(membership_id: results&.dig('membershipId'))

      user.unique_name              = results&.dig('uniqueName')
      user.display_name             = results&.dig('displayName')
      user.psn_display_name         = results&.dig('psn_display_name')
      user.xbox_display_name        = results&.dig('xbox_display_name')
      user.blizzard_display_name    = results&.dig('blizzardDisplayName')
      user.steam_display_name       = results&.dig('steamDisplayName')
      user.stadia_display_name      = results&.dig('stadiaDisplayName')
      user.twitch_display_name      = results&.dig('twitchDisplayName')
      user.bungie_display_name      = results&.dig('cachedBungieGlobalDisplayName')
      user.bungie_display_name_code = results&.dig('cachedBungieGlobalDisplayNameCode')
      user.about                    = results&.dig('about')
      user.first_accessed_at        = DateTime.parse(results&.dig('firstAccess'))
      user.last_updated_at          = DateTime.parse(results&.dig('lastUpdate'))

      user.save

      user
    end
  end
end
