# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net user
  class BungieUser < ActiveRecord::Base
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

      character             = BungieCharacter.find_or_create_by(bungie_user: self, character_id: character_row.dig('characterId'))
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

    def self.search_user_by_gamertag_and_platform(requested_gamertag, requested_platform)
      user_row = Bungie::Api.instance.search_user(requested_gamertag, requested_platform)

      unless user_row
        search_results = TrialsReport::Api.search_user(requested_gamertag, requested_platform)
        raise QueryError, "Couldn't find the requested user." unless search_results&.first

        user_row = Bungie::Api.instance.search_user(search_results&.first&.dig('displayName'), requested_platform)
        # results[:gamertag_suggestions] = search_results.map { |result| result&.dig('displayName') }
      end

      raise QueryError, "Couldn't find the requested user." unless user_row

      BungieUser.find_or_create_by(membership_id: user_row.dig('membershipId'))
    end
  end
end
