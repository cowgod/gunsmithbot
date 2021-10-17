# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class BungieMembership < ActiveRecord::Base
    belongs_to :bungie_user
    has_many :bungie_characters
    has_many :slack_users
    has_many :discord_users


    def bungie_name
      bungie_user&.bungie_name
    end


    def platform
      Bungie::Api.get_platform_code(membership_type)
    end


    def load_characters
      character_rows = Bungie::Api.instance.get_characters_with_equipment(membership_type, membership_id)
      raise QueryError, "Couldn't find characters for the requested user." unless character_rows

      characters = []

      character_rows.each_pair do |_, character_row|
        character             = BungieCharacter.find_or_create_by(character_id: character_row['characterId'])
        character.race_hash   = character_row['raceHash']
        character.race        = character_row['raceHash'] ###############
        character.class_hash  = character_row['classHash']
        character.class       = character_row['classHash'] ################
        character.gender_hash = character_row['genderHash']
        character.gender      = character_row['genderHash'] #################

        character.item_rows = character_row['items']

        character.save

        characters << character
      end

      characters
    end


    def load_active_character_with_equipment
      character_row = Bungie::Api.instance.active_char_with_equipment(membership_type, membership_id)
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character_row

      character             = BungieCharacter.find_or_create_by(bungie_membership: self, character_id: character_row['characterId'])
      character.race_hash   = character_row['raceHash']
      character.race_name   = character_row['raceHash'] ###############
      character.class_hash  = character_row['classHash']
      character.class_name  = character_row['classHash'] ################
      character.gender_hash = character_row['genderHash']
      character.gender_name = character_row['genderHash'] #################

      character.item_rows = character_row['items']

      character.save

      character
    end


    def self.search_membership_by_bungie_name(bungie_name)
      membership_rows = Bungie::Api.instance.get_memberships_for_bungie_name(bungie_name)
      raise QueryError, "Couldn't find the requested user." unless membership_rows&.count&.positive?

      select_and_update_primary_membership(membership_rows)
    end


    def self.search_membership_by_id(membership_id)
      results = Bungie::Api.instance.get_memberships_for_membership_id(membership_id)
      raise QueryError, "Couldn't find the requested user." unless results&.dig('destinyMemberships')

      select_and_update_primary_membership(results&.dig('destinyMemberships'))
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


      membership                 = BungieMembership.find_or_create_by(membership_id: membership_row['membershipId'])
      membership.membership_type = membership_row['membershipType']
      membership.display_name    = membership_row['displayName']

      membership.bungie_user = Bungie::BungieUser.search_user_by_platform_membership_id(membership.membership_id)

      membership.save

      membership
    end
  end
end

