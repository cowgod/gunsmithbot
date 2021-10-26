# frozen_string_literal: true


module Discord
  # Represent a Discord user's membership in a server
  class Membership < ActiveRecord::Base
    belongs_to :user, foreign_key: :discord_user_id
    belongs_to :server, foreign_key: :discord_server_id

    scope :notify_twitch_clips, -> { where(notify_twitch_clips: true) }
  end
end
