# frozen_string_literal: true


module Discord
  # Represent a Discord user
  class User < ActiveRecord::Base
    has_many :memberships, foreign_key: :discord_user_id
    has_many :servers, through: :memberships
    belongs_to :bungie_user, class_name: 'Bungie::User', optional: true

    scope :notification_servers, -> { joins(:memberships, :servers).where('membership.notify_twitch_clips = 1') }


    # Utility function to mention users in messages
    # @return [String] the mention code in the form of <@id>
    def mention
      "<@#{user_id}>"
    end


    def notification_servers
      memberships.notify_twitch_clips.map(&:server)
    end

  end
end
