# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net membership
  class BungieMembership < ActiveRecord::Base
    belongs_to :bungie_user
    has_many :bungie_characters
    has_many :slack_users
    has_many :discord_users

    def gamertag
      display_name
    end

    def platform
      Bungie::Api.get_platform_code(membership_type)
    end

    def load_characters
      character_rows = Bungie::Api.instance.get_characters_with_equipment(membership_type, membership_id)
      raise QueryError, "Couldn't find characters for the requested user." unless character_rows

      characters = []

      character_rows.each_pair do |_, character_row|
        character             = BungieCharacter.find_or_create_by(character_id: character_row.dig('characterId'))
        character.race_hash   = character_row.dig('raceHash')
        character.race        = character_row.dig('raceHash') ###############
        character.class_hash  = character_row.dig('classHash')
        character.class       = character_row.dig('classHash') ################
        character.gender_hash = character_row.dig('genderHash')
        character.gender      = character_row.dig('genderHash') #################

        character.item_rows = character_row.dig('items')

        character.save

        characters << character
      end

      characters
    end

    def load_active_character_with_equipment
      character_row = Bungie::Api.instance.active_char_with_equipment(membership_type, membership_id)
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character_row

      character             = BungieCharacter.find_or_create_by(bungie_membership: self, character_id: character_row.dig('characterId'))
      character.race_hash   = character_row.dig('raceHash')
      character.race_name   = character_row.dig('raceHash') ###############
      character.class_hash  = character_row.dig('classHash')
      character.class_name  = character_row.dig('classHash') ################
      character.gender_hash = character_row.dig('genderHash')
      character.gender_name = character_row.dig('genderHash') #################

      character.item_rows = character_row.dig('items')

      character.save

      character
    end

    def self.search_membership_by_gamertag_and_platform(requested_gamertag, requested_platform)
      membership_rows = Bungie::Api.instance.search_user(requested_gamertag, requested_platform)

      # unless user_row
      #   search_results = TrialsReport::Api.search_user(requested_gamertag, requested_platform)
      #   raise QueryError, "Couldn't find the requested user." unless search_results&.first
      #
      #   user_row = Bungie::Api.instance.search_user(search_results&.first&.dig('displayName'), requested_platform)
      #   # results[:gamertag_suggestions] = search_results.map { |result| result&.dig('displayName') }
      # end

      raise QueryError, "Couldn't find the requested user." unless membership_rows
      raise MultipleResultsError if membership_rows.count > 1

      membership                 = BungieMembership.find_or_create_by(membership_id: membership_rows[0].dig('membershipId'))
      membership.membership_type = membership_rows[0].dig('membershipType')
      membership.display_name    = membership_rows[0].dig('displayName')
      membership.save

      membership
    end


    def self.search_membership_by_id_and_platform(membership_id, requested_platform)
      # Transform the requested platform into a numeric ID
      membership_type_id = Bungie::Api.get_membership_type_id(requested_platform) || -1


      results = Bungie::Api.instance.get_memberships_for_membership_id(membership_id, requested_platform)

      raise QueryError, "Couldn't find the requested user." unless results&.dig('destinyMemberships')

      # Map the rows into a hash by their associated membership type
      membership_rows = results&.dig('destinyMemberships').map { |row| [row.dig('membershipType'), row] }.to_h

      if membership_rows.size == 1 || membership_type_id < 1
        # If we just got a single result, or they didn't specify a platform, just use the first result
        membership_row = membership_rows.shift[1]
      else
        # Otherwise, find the membership that matches the requested platform
        membership_row = membership_rows[membership_type_id]
      end

      # Take into account any cross save override
      if membership_row&.dig('crossSaveOverride').to_i && membership_rows[membership_row&.dig('crossSaveOverride').to_i]
        membership_row = membership_rows[membership_row&.dig('crossSaveOverride').to_i]
      end

      raise QueryError, "Couldn't find the requested user." unless membership_row

      membership                 = BungieMembership.find_or_create_by(membership_id: membership_row.dig('membershipId'))
      membership.membership_type = membership_row.dig('membershipType')
      membership.display_name    = membership_row.dig('displayName')
      membership.save

      membership
    end
  end
end
