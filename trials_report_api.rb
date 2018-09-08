require 'httparty'
require 'uri'
require 'pp'


class TrialsReportApi
  include HTTParty
  base_uri 'https://api.destinytrialsreport.com/destiny2/en/'


  def definitions
    self.class.get('DestinyDefinitions.json').parsed_response
  end

  def load_manifest
    data = definitions

    pp data

    # items = ', JSON.stringify(data.items))
    # this.set('perks', JSON.stringify(data.perks))
    # this.set('grid', JSON.stringify(data.talentGrid))
    # this.set('steps', JSON.stringify(data.steps))
    # return resolve(data)

  end

  # def search_user(gamertag)
  #   response = self.class.get("/Destiny2/SearchDestinyPlayer/-1/#{URI.escape(gamertag)}/", @options)
  #   response ? response.parsed_response['Response'][0] : nil
  #
  #   # response.parsed_response['Response'][0]['displayName']
  #   # response.parsed_response['Response'][0]['membershipId']
  # end

end