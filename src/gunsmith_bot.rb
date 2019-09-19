# frozen_string_literal: true

require_relative 'bungie_api'
require_relative 'trials_report_api'

require_relative 'query_error'

require 'mysql2'
require 'pp'

# The core class representing the bot's main interface
class GunsmithBot
  def initialize
    %w[BUNGIE_API_TOKEN GUNSMITH_DB_HOST GUNSMITH_DB_USER GUNSMITH_DB_PASS GUNSMITH_DB_NAME].each do |var_name|
      raise "Environment variable '#{var_name}' not set" unless ENV[var_name]
    end

    # this takes a hash of options, almost all of which map directly
    # to the familiar database.yml in rails
    # See http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/Mysql2Adapter.html
    @db_conn = Mysql2::Client.new(
      host:     ENV['GUNSMITH_DB_HOST'],
      username: ENV['GUNSMITH_DB_USER'],
      password: ENV['GUNSMITH_DB_PASS'],
      database: ENV['GUNSMITH_DB_NAME']
    )

    @bungie_api = BungieApi.new(ENV['BUNGIE_API_TOKEN'])
  end

  def query_user_and_platform(requested_gamertag, requested_platform)
    results = { gamertag_suggestions: [] }

    results[:user_info] = @bungie_api.search_user(requested_gamertag, requested_platform)

    unless results[:user_info]
      search_results = TrialsReportApi.search_user(requested_gamertag, requested_platform)
      raise QueryError, "Couldn't find the requested user." unless search_results&.first

      results[:user_info]            = @bungie_api.search_user(search_results&.first&.dig('displayName'), requested_platform)
      results[:gamertag_suggestions] = search_results.map { |result| result&.dig('displayName') }
    end

    raise QueryError, "Couldn't find the requested user." unless results[:user_info]

    results[:gamertag] = results[:user_info]&.dig('displayName')
    results[:platform] = BungieApi.get_platform_code(results[:user_info]&.dig('membershipType'))

    results
  end

  def query_slot(requested_slot)
    results = {}

    results[:bucket_id] = BungieApi.get_bucket_id(requested_slot)
    raise QueryError, "Couldn't find the requested slot." unless results[:bucket_id]

    results[:slot] = BungieApi.get_bucket_code(results[:bucket_id])

    results
  end

  def query(requested_gamertag, requested_platform, requested_slot)
    results = {}

    user_results = query_user_and_platform(requested_gamertag, requested_platform)
    user_info    = user_results.dig(:user_info)
    results.merge!(user_results)

    slot_results = query_slot(requested_slot)
    results.merge!(slot_results)

    character = @bungie_api.active_char_with_equipment(user_info['membershipType'], user_info['membershipId'])
    raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

    requested_item = character.dig('items').find { |item| item.dig('bucketHash') == slot_results[:bucket_id] }
    raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

    results[:item] = @bungie_api.item_details(user_info['membershipType'], user_info['membershipId'], requested_item['itemInstanceId'])
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

  def query_loadout(requested_gamertag, requested_platform, type = :full)
    results = {}

    user_results = query_user_and_platform(requested_gamertag, requested_platform)
    user_info    = user_results.dig(:user_info)
    results.merge!(user_results)

    character = @bungie_api.active_char_with_equipment(user_info['membershipType'], user_info['membershipId'])
    raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

    results[:slots] = {}

    slots_to_query = GunsmithBot.slots_for_loadout_type(type)

    BungieApi::ITEM_BUCKET_IDS.each_key do |slot|
      next unless slots_to_query.include?(slot)

      slot_results = query_slot(slot)

      requested_item = character.dig('items').find { |item| item.dig('bucketHash') == slot_results[:bucket_id] }
      raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

      results[:slots][slot] = @bungie_api.item_details(user_info['membershipType'], user_info['membershipId'], requested_item['itemInstanceId'])
      raise QueryError, "Couldn't load info for the requested item or armor piece." unless results[:slots][slot]
    end

    results
  end
end
