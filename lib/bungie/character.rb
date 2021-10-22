# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net character
  class Character < ActiveRecord::Base
    belongs_to :membership, foreign_key: 'bungie_membership_id'

    attr_accessor :activities
    attr_accessor :item_rows


    # def load_activities(mode: nil)
    #   activities = Bungie::Activities::Activity.load_activities_for_character(self, mode: mode)
    # end

    def load_unscanned_activities(mode: nil)
      activities = Bungie::Activities::Activity.load_unscanned_activities_for_character(self, mode: mode)
    end



    def self.load_characters_for_membership(membership, include_equipment: false)
      return nil unless membership


      characters = Bungie::Api.instance.get_characters_for_membership(membership.membership_type, membership.membership_id, include_equipment: include_equipment)
      return nil unless characters

      characters.transform_values do |character_hash|
        create_or_update_from_hash(character_hash, membership)
      end
    end


    def self.load_active_character_for_membership(membership, include_equipment: false)
      return nil unless membership


      character_hash = Bungie::Api.instance.get_active_character_for_membership(membership.membership_type, membership.membership_id, include_equipment: include_equipment)
      return nil unless character_hash

      create_or_update_from_hash(character_hash, membership)
    end



    def self.create_or_update_from_hash(character_hash, membership)
      return nil unless character_hash


      character = Bungie::Character.find_or_initialize_by(membership: membership, character_id: character_hash['characterId'].to_i)

      character.membership = membership
      character.race_hash  = character_hash['raceHash']
      # character.race_name   = character_hash['raceHash'] ###############
      character.class_hash = character_hash['classHash']
      # character.class_name  = character_hash['classHash'] ################
      character.gender_hash = character_hash['genderHash']
      # character.gender_name = character_hash['genderHash'] #################

      character.item_rows = character_hash['items']

      character.save

      character
    end

  end
end

