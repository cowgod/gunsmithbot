# frozen_string_literal: true

require 'singleton'
require 'httparty'
require 'cgi'
require 'time'

require_relative '../concerns/retryable'

require 'pp'

module Twitch
  # Class to encapsulate communication with the Bungie Destiny 2 API
  class Api
    include Singleton
    include HTTParty
    include Retryable

    base_uri 'https://api.twitch.tv/helix'

    SUCCESS_CODE = 200

    DESTINY_2_GAME_CODE = '497057'


    def initialize
      @client_id     = ENV['TWITCH_API_CLIENT_ID'].presence || $config&.dig('api_keys', 'twitch_client_id')
      @client_secret = ENV['TWITCH_API_CLIENT_SECRET'].presence || $config&.dig('api_keys', 'twitch_client_secret')

      raise 'Twitch Client ID not set' unless @client_id
      raise 'Twitch Client Secret not set' unless @client_secret


      Cowgod::Logger.log "#{self.class}.#{__method__} - Initializing Twitch API..."

      @options = {}
      get_access_token

      Cowgod::Logger.log "#{self.class}.#{__method__} - Done."
    end


    def get_access_token
      url = 'https://id.twitch.tv/oauth2/token'

      query_options = {
        grant_type:    'client_credentials',
        client_id:     @client_id,
        client_secret: @client_secret
      }

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.post(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE


      @access_token = response.parsed_response&.dig('access_token')

      @options = @options.merge(
        headers: {
          'Authorization' => "Bearer #{@access_token}",
          'Client-Id'     => @client_id
        }
      )


      @access_token
    end


    # Load the Twitch account for a given Twitch user ID
    def get_twitch_user_for_user_id(user_id)
      # If they didn't give us a user_id to search, there's nothing we can do
      return nil unless user_id

      url = '/users'

      query_options = {
        id: user_id
      }

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      response.parsed_response&.dig('data')&.first || {}
    end


    # Load the Twitch account for a given Twitch display name
    def get_twitch_user_for_display_name(display_name)
      # If they didn't give us a display_name to search, there's nothing we can do
      return nil unless display_name

      url = '/users'

      query_options = {
        login: display_name
      }

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      response.parsed_response&.dig('data')&.first || {}
    end


    # Load a Twitch video by its ID
    def get_twitch_video_for_video_id(video_id)
      # If they didn't give us a video_id to search, there's nothing we can do
      return nil unless video_id

      url = '/videos'

      query_options = {
        id: video_id
      }

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      results = response.parsed_response&.dig('data') || []


      # Convert the duration field to seconds
      results.map do |result|
        time_components    = result['duration'].match /((?<hours>\d+)h)?((?<minutes>\d+)m)?(?<seconds>\d+)s/
        result['duration'] = (3600 * time_components[:hours].to_i) + (60 * time_components[:minutes].to_i) + time_components[:seconds].to_i
      end


      results
    end


    # Load the Twitch account for a given Twitch display name
    def get_twitch_videos_for_user_id(user_id, game_id: nil)
      # If they didn't give us a user_id to search, there's nothing we can do
      return nil unless user_id

      url = '/videos'

      query_options           = {
        user_id: user_id
      }

      query_options[:game_id] = game_id if game_id

      Cowgod::Logger.log "#{self.class}.#{__method__} - #{url} - #{JSON.pretty_generate(query_options)}"

      response = with_retry do
        self.class.get(
          url,
          @options.merge(
            query: query_options
          )
        )
      end
      raise QueryError, 'API request failed' unless response && response.code == SUCCESS_CODE

      results = response.parsed_response&.dig('data') || []


      # Convert the duration field to seconds
      results.map do |result|
        time_components    = result['duration'].match /((?<hours>\d+)h)?((?<minutes>\d+)m)?(?<seconds>\d+)s/
        result['duration'] = (3600 * time_components[:hours].to_i) + (60 * time_components[:minutes].to_i) + time_components[:seconds].to_i
      end


      results
    end
  end
end


