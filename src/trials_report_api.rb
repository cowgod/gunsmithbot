require 'httparty'
require 'uri'

require_relative 'bungie_api'


require 'pp'

class TrialsReportApi
  def self.search_user(requested_gamertag, requested_platform)
    membership_type_id = BungieApi.get_membership_type_id(requested_platform) || 0

    url      = "https://elastic.destinytrialsreport.com/players/#{URI.escape(membership_type_id.to_s)}/#{URI.escape(requested_gamertag.to_s)}/"
    response = HTTParty.get(url)

    response ? response.parsed_response : nil
  end
end