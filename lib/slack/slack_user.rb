# frozen_string_literal: true

require_relative 'slack_team'
require_relative '../bungie/bungie_user'


module Slack
  # Represent a Slack user
  class SlackUser < ActiveRecord::Base
    belongs_to :slack_team
    belongs_to :bungie_user, class_name: 'Bungie::BungieUser', optional: true
  end
end
