require_relative 'bungie_api'
require_relative 'trials_report_api'

require_relative 'query_error'

require 'pp'


class GunsmithBot
  def initialize
    raise 'BUNGIE_API_KEY not set' unless ENV['BUNGIE_API_TOKEN']
    @bungie_api = BungieApi.new(ENV['BUNGIE_API_TOKEN'])
  end

  def query(requested_gamertag, requested_platform, requested_slot)
    results = {}


    bucket_id = BungieApi.get_bucket_id(requested_slot)
    raise QueryError, "Couldn't find the requested slot." unless bucket_id

    results[:slot] = BungieApi.get_bucket_code(bucket_id)

    results[:gamertag_suggestions] = []

    user_info = @bungie_api.search_user(requested_gamertag, requested_platform)

    unless user_info
      search_results = TrialsReportApi.search_user(requested_gamertag, requested_platform)
      raise QueryError, "Couldn't find the requested user." unless search_results&.first

      user_info                      = @bungie_api.search_user(search_results&.first&.dig('displayName'), requested_platform)
      results[:gamertag_suggestions] = search_results.map { |result| result&.dig('displayName') }
    end

    raise QueryError, "Couldn't find the requested user." unless user_info

    results[:gamertag] = user_info&.dig('displayName')
    results[:platform] = BungieApi.get_platform_code(user_info&.dig('membershipType'))

    character = @bungie_api.active_char_with_equipment(user_info['membershipType'], user_info['membershipId'])
    raise QueryError, "Couldn't find the most recently used character for the requested user." unless character

    requested_item = character.dig('items').find { |item| item.dig('bucketHash') == bucket_id }
    raise QueryError, "Couldn't find the requested item or armor piece." unless requested_item

    results[:item] = @bungie_api.item_details(user_info['membershipType'], user_info['membershipId'], requested_item['itemInstanceId'])
    raise QueryError, "Couldn't load info for the requested item or armor piece." unless results[:item]

    results
  end
end

