# frozen_string_literal: true

require 'singleton'
require 'pp'

module Gunsmith
  # The core class representing the bot's main interface
  class Bot
    BOT_GITHUB_URL = 'https://github.com/cowgod/gunsmithbot'

    include Singleton


    def query_slot(requested_slot)
      results = {}

      results[:bucket_id] = Bungie::Api.get_bucket_id(requested_slot)
      raise QueryError, "Couldn't find the requested slot." unless results[:bucket_id]

      results[:slot] = Bungie::Api.get_bucket_code(results[:bucket_id])

      results
    end


    def query(bungie_membership, requested_slot)
      results = {}

      results[:bungie_membership] = bungie_membership

      slot_results = query_slot(requested_slot)
      results.merge!(slot_results)

      character = bungie_membership.load_active_character_with_equipment
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

      requested_item = character.item_rows.find { |item| item.dig('bucketHash') == slot_results[:bucket_id] }
      raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

      results[:item] = Bungie::Api.instance.item_details(bungie_membership.membership_type, bungie_membership.membership_id, requested_item['itemInstanceId'])
      raise QueryError, "Couldn't load info for the requested item or armor piece." unless results[:item]

      results
    end


    def self.slots_for_loadout_type(type = :full)
      case type.to_sym
      when :weapons
        %i[KINETIC_WEAPON ENERGY_WEAPON HEAVY_WEAPON GHOST SUBCLASS]
      when :armor
        %i[HEAD ARMS CHEST LEGS CLASS_ITEM GHOST SUBCLASS]
      else
        %i[KINETIC_WEAPON ENERGY_WEAPON HEAVY_WEAPON HEAD ARMS CHEST LEGS CLASS_ITEM GHOST SUBCLASS]
      end
    end


    def query_loadout(bungie_membership, type = :full)
      results = {}

      results[:bungie_membership] = bungie_membership

      character = bungie_membership.load_active_character_with_equipment
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

      results[:slots] = {}

      slots_to_query = Gunsmith::Bot.slots_for_loadout_type(type)

      Bungie::Api::ITEM_BUCKET_IDS.each_key do |slot|
        next unless slots_to_query.include?(slot)

        slot_results = query_slot(slot)

        requested_item = character.item_rows.find { |item| item.dig('bucketHash') == slot_results[:bucket_id] }
        raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

        results[:slots][slot] = Bungie::Api.instance.item_details(bungie_membership.membership_type, bungie_membership.membership_id, requested_item['itemInstanceId'])
        raise QueryError, "Couldn't load info for the requested item or armor piece." unless results[:slots][slot]
      end

      results
    end



    ###### UNUSED SO FAR
    def load_pgcrs_for_membership(bungie_membership)
      results[:bungie_membership] = bungie_membership

      character = bungie_membership.load_characters
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

    end
  end
end
