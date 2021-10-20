# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net character
  class Activity < ActiveRecord::Base
    has_many :teams
    has_many :players

    attr_accessor :item_rows


    def load_activities(mode: nil)
      Bungie::Api.instance.get_activities_for_character(bungie_membership&.membership_type, bungie_membership&.membership_id, character_id, mode: mode)
    end


    def self.load_characters_for_bungie_membership(bungie_membership, include_equipment: false)
      return nil unless bungie_membership


      characters = Bungie::Api.instance.get_characters_for_membership(bungie_membership.membership_type, bungie_membership.membership_id, include_equipment: include_equipment)
      raise QueryError, "Couldn't find characters for the requested user." unless characters

      characters.transform_values do |character_hash|
        create_or_update_from_hash(character_hash, bungie_membership)
      end
    end


    def self.load_active_character_for_bungie_membership(bungie_membership, include_equipment: false)
      return nil unless bungie_membership


      character_hash = Bungie::Api.instance.get_active_character_for_membership(bungie_membership.membership_type, bungie_membership.membership_id, include_equipment: include_equipment)
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character_hash

      create_or_update_from_hash(character_hash, bungie_membership)
    end



    def self.create_or_update_from_hash(character_hash, bungie_membership)
      return nil unless character_hash


      character             = Bungie::Character.find_or_initialize_by(bungie_membership: bungie_membership, character_id: character_hash['characterId'].to_i)
      character.race_hash   = character_hash['raceHash']
      character.race_name   = character_hash['raceHash'] ###############
      character.class_hash  = character_hash['classHash']
      character.class_name  = character_hash['classHash'] ################
      character.gender_hash = character_hash['genderHash']
      character.gender_name = character_hash['genderHash'] #################

      character.item_rows = character_hash['items']

      character.save

      character
    end

  end
end

