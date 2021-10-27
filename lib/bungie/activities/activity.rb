# frozen_string_literal: true

module Bungie
  module Activities
    # Represent a Destiny activity
    class Activity < ActiveRecord::Base
      self.table_name = 'bungie_activities'


      has_many :teams, foreign_key: 'bungie_activity_id'
      has_many :players, foreign_key: 'bungie_activity_id'


      ACTIVITIES_PER_PAGE = 25
      MAX_PAGES_PER_CALL  = 4


      # def load_activities(mode: nil)
      #   Bungie::Api.instance.get_activities_for_character(membership&.membership_type, membership&.membership_id, character_id, mode: mode)
      #
      # end


      def ended_at
        started_at + duration
      end


      def map_manifest_entry
        Bungie::Api.instance.manifest.lookup_activity(reference_id)
      end


      def map_name
        map_manifest_entry&.dig('displayProperties', 'name')
      end


      def map_thumbnail_url
        "https://www.bungie.net/#{map_manifest_entry['pgcrImage']&.sub(%r{^/}, '') || 'img/theme/destiny/bgs/pgcrs/placeholder.jpg'}"
      end


      def activity_manifest_entry
        Bungie::Api.instance.manifest.lookup_activity(director_activity_hash)
      end


      def activity_name
        activity_manifest_entry&.dig('displayProperties', 'name')
      end


      def tracked_players
        players&.find_twitch_clips
      end


      def self.load_unscanned_activities_for_character(character, mode: nil)
        raise ArgumentError unless character


        # Initialize the output hash
        activities = {}

        # Continue loading activities until we run out of ones we haven't scanned (or we hit our configured limit)
        (0..MAX_PAGES_PER_CALL - 1).each do |page_number|
          page_activities = Bungie::Api.instance.get_activities_for_character(
            character.membership.membership_type,
            character.membership.membership_id,
            character.character_id,
            mode:           mode,
            num_activities: ACTIVITIES_PER_PAGE,
            page_number:    page_number
          )


          # For each activity that exists in our DB, replace it with the instantiated object. Leave the rest as the hash
          page_activities.transform_values! { |activity| find_by(instance_id: activity.dig('activityDetails', 'instanceId').to_i) || activity }

          # Filter out any activities we've scanned previously
          page_activities.reject! { |activity_id, activity| activity.respond_to?(:scanned_at) && activity&.scanned_at&.present? }

          # If we didn't get a single unscanned activity in this page, consider us done
          break if page_activities.empty?

          # Convert any remaining activity hashes to a Activity object by looking them up in the DB
          page_activities.transform_values! { |activity| activity.is_a?(Hash) ? create_or_update_from_hash(activity) : activity }

          activities.merge! page_activities
        end


        activities
      end


      #   def self.load_active_character_for_bungie_membership(bungie_membership, include_equipment: false)
      #     return nil unless bungie_membership
      #
      #
      #     character_hash = Bungie::Api.instance.get_active_character_for_membership(bungie_membership.membership_type, bungie_membership.membership_id, include_equipment: include_equipment)
      #     return nil unless character_hash
      #
      #     create_or_update_from_hash(character_hash, bungie_membership)
      #   end


      # Instantiate or update the object using a hash returned by the API.
      def self.create_or_update_from_hash(activity_hash)
        return nil unless activity_hash


        # Load PGCR for the activity from the API
        post_game_carnage_report = Bungie::Api.instance.get_pgcr_for_activity(activity_hash.dig('activityDetails', 'instanceId').to_i)


        activity = find_or_initialize_by(instance_id: activity_hash.dig('activityDetails', 'instanceId').to_i)

        activity.started_at             = Time.parse(activity_hash['period']) if activity_hash['period']
        activity.mode                   = activity_hash.dig('activityDetails', 'mode').to_i
        activity.modes                  = activity_hash.dig('activityDetails', 'modes').sort.join(',')
        activity.reference_id           = activity_hash.dig('activityDetails', 'referenceId').to_i
        activity.director_activity_hash = activity_hash.dig('activityDetails', 'directorActivityHash').to_i
        activity.duration               = activity_hash.dig('values', 'activityDurationSeconds', 'basic', 'value').to_i
        activity.is_private             = ActiveModel::Type::Boolean.new.cast(activity_hash.dig('activityDetails', 'isPrivate'))

        activity.save


        teams = {}
        post_game_carnage_report['teams']&.each do |team_hash|
          team           = Bungie::Activities::Team.find_or_initialize_by(activity: activity, team_id: team_hash['teamId'].to_i)
          team.team_name = team_hash['teamName']
          team.standing  = team_hash.dig('standing', 'basic', 'value')
          team.score     = team_hash.dig('score', 'basic', 'value')
          team.save

          teams[team.team_id] = team
        end


        post_game_carnage_report['entries'].each do |player_hash|
          character = Bungie::Character.find_by(character_id: player_hash['characterId'].to_i)
          unless character
            membership = Bungie::Membership.load_by_id(player_hash.dig('player', 'destinyUserInfo', 'membershipId'))

            if membership
              character              = Bungie::Character.new
              character.membership   = membership
              character.character_id = player_hash['characterId'].to_i
              character.save
            end
          end

          player          = Bungie::Activities::Player.find_or_initialize_by(activity: activity, character: character)
          player.team     = teams[player_hash.dig('values', 'team', 'basic', 'value').to_i]
          player.kills    = player_hash.dig('values', 'kills', 'basic', 'value')
          player.assists  = player_hash.dig('values', 'assists', 'basic', 'value')
          player.deaths   = player_hash.dig('values', 'deaths', 'basic', 'value')
          player.standing = player_hash['standing']
          player.score    = player_hash.dig('score', 'basic', 'value')
          player.save
        end


        activity
      end


    end
  end
end

