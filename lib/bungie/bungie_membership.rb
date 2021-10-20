# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class BungieMembership < ActiveRecord::Base
    belongs_to :bungie_user
    has_many :bungie_characters


    def bungie_name
      bungie_user&.bungie_name
    end


    def platform
      Bungie::Api.get_platform_code(membership_type)
    end


    def load_characters
      bungie_characters = Bungie::BungieCharacter.load_characters_for_bungie_membership(self)
    end


    def load_active_character_with_equipment
      Bungie::BungieCharacter.load_active_character_for_bungie_membership(self, include_equipment: true)
    end


    def self.load_by_id(membership_id)
      results = Bungie::Api.instance.get_memberships_for_membership_id(membership_id)
      raise QueryError, "Couldn't find the requested user." unless results&.dig('destinyMemberships')

      select_and_update_primary_membership(results&.dig('destinyMemberships'))
    end


    def self.load_by_bungie_name(bungie_name)
      membership_rows = Bungie::Api.instance.get_memberships_for_bungie_name(bungie_name)
      raise QueryError, "Couldn't find the requested user." unless membership_rows&.count&.positive?

      select_and_update_primary_membership(membership_rows)
    end


    def self.select_and_update_primary_membership(membership_rows)
      # Map the rows into a hash by their associated membership type
      membership_rows = membership_rows.map { |row| [row['membershipType'], row] }.to_h


      # Use the first account we find. Technically, if they have multiple accounts but cross-save disabled, we should
      # let them specify a platform and find the right one, but I suspect this is a very small fraction of users. So
      # until someone requests this functionality, we'll avoid over-complicating the code
      membership_row = membership_rows&.dig(membership_rows&.keys&.first)


      # Take into account any cross save override
      if membership_row&.dig('crossSaveOverride').to_i && membership_rows[membership_row&.dig('crossSaveOverride').to_i]
        membership_row = membership_rows[membership_row&.dig('crossSaveOverride').to_i]
      end


      bungie_user = Bungie::BungieUser.load_by_destiny_membership_id(membership_row['membershipId'])


      membership                 = BungieMembership.find_or_initialize_by(bungie_user: bungie_user, membership_id: membership_row['membershipId'])
      membership.membership_type = membership_row['membershipType']
      membership.display_name    = membership_row['displayName']

      membership.save

      membership
    end
  end
end

