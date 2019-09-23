# frozen_string_literal: true

require_relative '../bungie/bungie_user'


module Discord
  # Represent a Discord user
  class DiscordUser < ActiveRecord::Base
    belongs_to :bungie_user, class_name: 'Bungie::BungieUser', optional: true
  end
end
