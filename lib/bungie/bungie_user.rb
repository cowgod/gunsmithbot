# frozen_string_literal: true

module Bungie
  # Represent a Bungie.net user
  class BungieUser < ActiveRecord::Base
    has_many :slack_users
    has_many :discord_users
  end
end
