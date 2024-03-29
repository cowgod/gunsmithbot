require 'httparty'
require 'cgi'


require 'pp'

module TrialsReport
  class Api
    def self.search_user(requested_gamertag, requested_platform)
      # If they didn't give us a gamertag to search, there's nothing we can do
      return nil unless requested_gamertag

      membership_type_id = Bungie::Api.get_membership_type_id(requested_platform) || 0

      url      = "https://elastic.destinytrialsreport.com/players/#{membership_type_id.to_s.uri_encode}/#{requested_gamertag.to_s.uri_encode}/"
      response = HTTParty.get(url)

      response ? response.parsed_response : nil
    end
  end
end