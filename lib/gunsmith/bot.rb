# frozen_string_literal: true

require 'singleton'
require 'pp'

module Gunsmith
  # The core class representing the bot's main interface
  class Bot
    BOT_GITHUB_URL = 'https://github.com/cowgod/gunsmithbot'

    include Singleton

    def query_user_and_platform(requested_gamertag, requested_platform)
      results = { gamertag_suggestions: [] }

      results[:user_info] = Bungie::Api.instance.search_user(requested_gamertag, requested_platform)

      unless results[:user_info]
        search_results = TrialsReport::Api.search_user(requested_gamertag, requested_platform)
        raise QueryError, "Couldn't find the requested user." unless search_results&.first

        results[:user_info]            = Bungie::Api.instance.search_user(search_results&.first&.dig('displayName'), requested_platform)
        results[:gamertag_suggestions] = search_results.map { |result| result&.dig('displayName') }
      end

      raise QueryError, "Couldn't find the requested user." unless results[:user_info]

      results[:gamertag] = results[:user_info]&.dig('displayName')
      results[:platform] = Bungie::Api.get_platform_code(results[:user_info]&.dig('membershipType'))

      results[:bungie_user] = Bungie::BungieUser.find_or_create_by(membership_id: results[:user_info]&.dig('membershipId')) do |new_user|
        new_user.membership_type = results[:user_info]&.dig('membershipType')
        new_user.display_name    = results[:user_info]&.dig('displayName')
      end

      results
    end


    def query_slot(requested_slot)
      results = {}

      results[:bucket_id] = Bungie::Api.get_bucket_id(requested_slot)
      raise QueryError, "Couldn't find the requested slot." unless results[:bucket_id]

      results[:slot] = Bungie::Api.get_bucket_code(results[:bucket_id])

      results
    end


    def query(bungie_user, requested_slot)
      results = {}

      results[:bungie_user] = bungie_user

      slot_results = query_slot(requested_slot)
      results.merge!(slot_results)

      character = bungie_user.load_active_character_with_equipment
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

      requested_item = character.item_rows.find { |item| item.dig('bucketHash') == slot_results[:bucket_id] }
      raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

      results[:item] = Bungie::Api.instance.item_details(bungie_user.membership_type, bungie_user.membership_id, requested_item['itemInstanceId'])
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


    def query_loadout(bungie_user, type = :full)
      results = {}

      results[:bungie_user] = bungie_user

      character = bungie_user.load_active_character_with_equipment
      raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

      results[:slots] = {}

      slots_to_query = Gunsmith::Bot.slots_for_loadout_type(type)

      Bungie::Api::ITEM_BUCKET_IDS.each_key do |slot|
        next unless slots_to_query.include?(slot)

        slot_results = query_slot(slot)

        requested_item = character.item_rows.find { |item| item.dig('bucketHash') == slot_results[:bucket_id] }
        raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

        results[:slots][slot] = Bungie::Api.instance.item_details(bungie_user.membership_type, bungie_user.membership_id, requested_item['itemInstanceId'])
        raise QueryError, "Couldn't load info for the requested item or armor piece." unless results[:slots][slot]
      end

      results
    end
  end
end
