# frozen_string_literal: true

require_relative 'slack_team'
require_relative '../bungie/bungie_membership'


module Slack
  # Represent a Slack user
  class SlackUser < ActiveRecord::Base
    belongs_to :slack_team
    belongs_to :bungie_membership, class_name: 'Bungie::BungieMembership', optional: true
  end
end
