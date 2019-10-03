# frozen_string_literal: true

require_relative '../bungie/bungie_membership'


module Discord
  # Represent a Discord user
  class DiscordUser < ActiveRecord::Base
    belongs_to :bungie_membership, class_name: 'Bungie::BungieMembership', optional: true
  end
end
