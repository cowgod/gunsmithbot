require 'httparty'
require 'uri'
require 'pp'


class TrialsReportApi
  include HTTParty
  base_uri 'https://api.destinytrialsreport.com/destiny2/en/'

  attr_accessor(:manifest)


  def load_manifest
    self.manifest = self.class.get('/DestinyDefinitions.json').parsed_response
  end
end