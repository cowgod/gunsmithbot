# frozen_string_literal: true


module Discord
  # Represent a Discord server
  class Server < ActiveRecord::Base
    has_many :memberships, foreign_key: :discord_server_id
    has_many :users, through: :memberships
  end
end
