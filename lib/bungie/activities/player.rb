# frozen_string_literal: true

module Bungie
  module Activities
    # Represent a player in a Destiny activity
    class Player < ActiveRecord::Base
      belongs_to :activity, foreign_key: 'bungie_activity_id'
      belongs_to :team, foreign_key: 'bungie_activity_team_id'
      belongs_to :character, class_name: 'Bungie::Character', foreign_key: 'bungie_character_id'

      scope :with_twitch_account, lambda {
        joins(character: { membership: :bungie_user })
          .where
          .not(
            characters: {
              memberships: {
                bungie_users: {
                  twitch_user:         nil,
                  twitch_display_name: nil
                }
              }
            }
          )
      }


      def bungie_user
        character&.membership&.bungie_user
      end


      def kd(decimal_places: 2)
        (kills.to_f / [deaths, 1].max).round(decimal_places)
      end
    end
  end
end

